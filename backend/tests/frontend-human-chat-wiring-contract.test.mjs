import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');

test('human chat UI uses messaging endpoints and exposes job/admin routes',()=>{
  const repo=read('lib/core/chat/chat_repository.dart');
  const page=read('lib/features/chat/chat_page.dart');
  const routes=read('lib/core/router/app_routes.dart');
  assert.match(repo,/\/messaging\/conversations/);
  assert.doesNotMatch(page,/HOPE Assistant|Ask HOPE anything/);
  assert.match(routes,/jobChat\(String jobId\)/);
  assert.match(routes,/adminChat\(\)/);
});


test('Indigo Atelier chat exposes working inbox organization, search, and live conversation signals',()=>{
  const page=read('lib/features/chat/chat_page.dart');
  const repository=read('lib/core/chat/chat_repository.dart');
  const theme=read('lib/core/theme/hope_v2_design.dart');
  for(const marker of [
    '_searchQuery','chat-inbox-search','UNREAD','IMPORTANT','PROJECTS','ARCHIVED',
    "updatePreferences(conversation.id",'markRead(conversation.id)',
    'listPresence(conversation.id)','در حال نوشتن','Typing…',
    "message.readReceipts.any",'chat-conversation-context',
  ]) assert.ok(page.includes(marker),marker);
  for(const marker of [
    'sendMessageWithAttachments','uploadChatFile','downloadAttachment',
    'markRead','updatePresence','listPresence','updatePreferences',
    'readReceipts','attachments',
  ]) assert.ok(repository.includes(marker),marker);
  assert.match(theme,/static const primary = Color\(0xFF6366F1\)/);
  assert.match(theme,/static const darkBackground = Color\(0xFF070A12\)/);
});

test('chat attachments and voice notes are connected to native Android recording and playback',()=>{
  const page=read('lib/features/chat/chat_page.dart');
  const bridge=read('lib/core/chat/chat_voice_bridge.dart');
  const native=read('android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt');
  const manifest=read('android/app/src/main/AndroidManifest.xml');
  for(const marker of ['_pickAndSendAttachments','_sendFiles','_saveAttachment','_playVoiceMessage','_toggleVoiceRecording'])
    assert.ok(page.includes(marker),marker);
  assert.match(bridge,/MethodChannel\('hope\.chat\/voice'\)/);
  assert.match(page,/HopeChatVoiceBridge\.playbackCompleted\.listen/);
  assert.match(page,/_playingVoiceMessageId = null/);
  assert.match(bridge,/call\.method\s*={1,2}\s*'playbackCompleted'/);
  assert.match(native,/invokeMethod\("playbackCompleted"/);
  for(const marker of ['startRecording','stopRecording','playFile','stopPlayback'])
    assert.ok(native.includes('"'+marker+'"'),marker);
  assert.match(native,/Manifest\.permission\.RECORD_AUDIO/);
  assert.match(manifest,/android\.permission\.RECORD_AUDIO/);
});
