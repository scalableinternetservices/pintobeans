import { Card, CardContent, CardHeader } from '@/components/ui/card';
import type { Message } from '@/types';

interface MessageListProps {
  messages: Message[];
  mode: 'user' | 'expert';
}

export default function MessageList({ messages, mode }: MessageListProps) {
  if (messages.length === 0) {
    return (
      <div className="text-sm text-gray-500 text-center py-8">
        {mode === 'user'
          ? 'No messages yet. Ask your question to get started.'
          : 'No messages yet. Claim the conversation to reply.'}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {messages.map((message, index) => {
        const isExpert = message.senderRole === 'expert';
        const prevMessage = index > 0 ? messages[index - 1] : null;

        // Check if this might be an auto-reply (expert message within 5 seconds of user message)
        const isPossiblyAutoReply = isExpert &&
          prevMessage &&
          prevMessage.senderRole === 'initiator' &&
          (new Date(message.timestamp).getTime() - new Date(prevMessage.timestamp).getTime()) < 5000;

        return (
          <Card
            key={message.id}
            className={isExpert ? 'border-l-4 border-l-blue-500' : ''}
          >
            <CardHeader>
              <div className="flex justify-between items-start">
                <div className="flex items-center gap-2">
                  <span className="font-bold">{message.senderUsername}</span>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${
                    isExpert
                      ? 'bg-blue-100 text-blue-800'
                      : 'bg-gray-100 text-gray-800'
                  }`}>
                    {isExpert ? 'Expert' : 'User'}
                  </span>
                  {isPossiblyAutoReply && (
                    <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-800 flex items-center gap-1">
                      🤖 AI Response
                    </span>
                  )}
                </div>
                <span className="text-sm text-gray-500">
                  {new Date(message.timestamp).toLocaleTimeString()}
                </span>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-left whitespace-pre-wrap">{message.content}</p>
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
