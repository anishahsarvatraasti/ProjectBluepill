import base64
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from agents.models.chatcmpl_converter import Converter
from app.services.audio_input import prepare_attachments
from app.agents.bluepill_agent import run_bluepill_agent
from app.api.agent_chat import AgentChatRequest, agent_chat
from app.security.supabase_auth import AuthenticatedUser

AUDIO = {'name': 'note.wav', 'mime_type': 'audio/wav', 'audio_format': 'wav',
         'audio_base64': base64.b64encode(b'private-audio').decode()}


class DirectAudioTest(unittest.IsolatedAsyncioTestCase):
    def test_validate_and_strip_audio_for_storage(self):
        metadata, audio = prepare_attachments([AUDIO])
        self.assertNotIn('audio_base64', metadata[0])
        self.assertEqual(metadata[0]['size_bytes'], 13)
        self.assertEqual(audio, [{**AUDIO, 'size_bytes': 13}])

    def test_invalid_data_and_formats_rejected(self):
        for item in [{**AUDIO, 'audio_base64': 'invalid!'},
                     {**AUDIO, 'audio_format': 'exe'},
                     {**AUDIO, 'audio_base64': ''},
                     {'mime_type': 'audio/wav'}]:
            with self.assertRaises(HTTPException):
                prepare_attachments([item])

    async def test_sdk_receives_real_audio_content_not_prompt_text(self):
        settings = SimpleNamespace(ai_provider='openrouter')
        run = AsyncMock(return_value=SimpleNamespace(final_output='Heard you.'))
        with patch('app.agents.bluepill_agent.get_settings', return_value=settings), \
             patch('app.agents.bluepill_agent._model_runtime', return_value=('audio-model', object())), \
             patch('app.agents.bluepill_agent.Runner.run', run):
            result = await run_bluepill_agent(message='Listen', user_context={}, memories=[], attachments=[AUDIO])
        self.assertEqual(result['text'], 'Heard you.')
        args = run.call_args.args
        content = args[1][0]['content']
        self.assertNotIn(AUDIO['audio_base64'], content[0]['text'])
        self.assertEqual(content[1]['input_audio']['data'], AUDIO['audio_base64'])
        # Verify the installed SDK really converts this to Chat Completions audio.
        converted = Converter.items_to_messages(args[1])
        self.assertEqual(converted[0]['content'][1]['type'], 'input_audio')
        self.assertEqual(converted[0]['content'][1]['input_audio']['format'], 'wav')

    async def test_api_persists_only_metadata_and_forwards_ephemeral_audio(self):
        store = SimpleNamespace(
            insert=AsyncMock(side_effect=[{'id': 'conversation'}, {'id': 'message'}, {'id': 'run'}]),
            update_by_id=AsyncMock(),
            select_by_id=AsyncMock(return_value={'status': 'completed'}),
        )
        process = AsyncMock()
        with patch('app.api.agent_chat.SupabaseRestClient', return_value=store), \
             patch('app.api.agent_chat.write_audit_log', AsyncMock()), \
             patch('app.api.agent_chat.process_agent_run', process):
            await agent_chat(AgentChatRequest(message='Listen', attachments=[AUDIO]), AuthenticatedUser(id='user'))
        self.assertNotIn(AUDIO['audio_base64'], str(store.insert.call_args_list))
        self.assertEqual(process.call_args.kwargs['audio_attachments'][0]['audio_base64'], AUDIO['audio_base64'])

    async def test_provider_credit_failure_is_safe_and_actionable(self):
        class CreditError(Exception):
            status_code = 402
        settings = SimpleNamespace(ai_provider='openrouter')
        with patch('app.agents.bluepill_agent.get_settings', return_value=settings), \
             patch('app.agents.bluepill_agent._model_runtime', return_value=('audio-model', object())), \
             patch('app.agents.bluepill_agent.Runner.run', AsyncMock(side_effect=CreditError('private-audio'))):
            with self.assertRaises(ValueError) as caught:
                await run_bluepill_agent(message='Listen', user_context={}, memories=[], attachments=[AUDIO])
        self.assertIn('account credit', str(caught.exception))
        self.assertNotIn('private-audio', str(caught.exception))
