import { Button } from '@/components/ui/button';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import type { Conversation, Message } from '@/types';
import { useRef, useEffect } from 'react';

interface ConversationViewProps {
  conversation?: Conversation | null;
  messages: Message[];
  mode: 'user' | 'expert';
  currentExpert?: string;
  onSendMessage: (content: string) => void;
  onClaimConversation: (id: string) => void;
  onBackToDashboard?: () => void;
}

export default function ConversationView({
  conversation,
  messages,
  mode,
  currentExpert,
  onSendMessage,
  onClaimConversation,
  onBackToDashboard,
}: ConversationViewProps) {
  const isClaimedByMe = conversation?.assignedExpertId === currentExpert;
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  if (!conversation) {
    return (
      <div className="text-sm text-gray-500 text-center py-8">
        Select a conversation to begin.
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Conversation Header */}
      <div className="mb-4 border-b pb-3">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-3">
            {mode === 'expert' && onBackToDashboard && (
              <Button variant="outline" size="sm" onClick={onBackToDashboard}>
                ← Dashboard
              </Button>
            )}
            <h3 className="text-base text-left font-semibold break-words max-w-[60ch]">
              {conversation.title}
            </h3>
            <span
              className={`text-xs px-2 py-0.5 rounded-full border ${
                conversation.assignedExpertId ? '' : 'opacity-70'
              }`}
            >
              {conversation.assignedExpertId
                ? `Assigned Expert: ${conversation.assignedExpertUsername || conversation.assignedExpertId}`
                : 'Waiting for Expert'}
            </span>
          </div>
          {mode === 'expert' &&
            conversation.assignedExpertId !== currentExpert && (
              <Button
                size="sm"
                onClick={() => onClaimConversation(conversation.id)}
              >
                Claim
              </Button>
            )}
        </div>
        {/* AI-Generated Summary */}
        {conversation.summary && conversation.summary !== "Generating summary..." && (
          <div className="mt-2 px-3 py-2 bg-blue-50 border border-blue-200 rounded-md">
            <div className="flex items-start gap-2">
              <span className="text-xs font-medium text-blue-700 mt-0.5 flex-shrink-0">
                📝 Summary:
              </span>
              <p className="text-xs text-blue-900 flex-1 text-left">
                {conversation.summary}
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto mb-4">
        <MessageList messages={messages} mode={mode} />
        <div ref={messagesEndRef} />
      </div>

      {/* Message Input */}
      <div className="flex-shrink-0 pb-4">
        <MessageInput
          conversation={conversation}
          mode={mode}
          onSendMessage={onSendMessage}
          isClaimedByMe={isClaimedByMe}
        />
      </div>
    </div>
  );
}
