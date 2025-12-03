import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { X, Plus } from 'lucide-react';

interface FAQItem {
  question: string;
  answer: string;
}

interface FAQEditorProps {
  faq: FAQItem[];
  onFAQChange: (faq: FAQItem[]) => void;
  disabled?: boolean;
}

export default function FAQEditor({
  faq,
  onFAQChange,
  disabled = false,
}: FAQEditorProps) {
  const [newQuestion, setNewQuestion] = useState('');
  const [newAnswer, setNewAnswer] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const addFAQItem = () => {
    if (newQuestion.trim() && newAnswer.trim()) {
      onFAQChange([...faq, { question: newQuestion.trim(), answer: newAnswer.trim() }]);
      setNewQuestion('');
      setNewAnswer('');
      setIsAdding(false);
    }
  };

  const removeFAQItem = (index: number) => {
    onFAQChange(faq.filter((_, i) => i !== index));
  };

  const updateFAQItem = (index: number, field: 'question' | 'answer', value: string) => {
    const updatedFAQ = [...faq];
    updatedFAQ[index][field] = value;
    onFAQChange(updatedFAQ);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          🤖 AI Auto-Response FAQ
        </CardTitle>
        <p className="text-sm text-gray-600">
          Add frequently asked questions and answers. The AI will automatically
          respond to matching questions from users.
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* FAQ list */}
        {faq.length > 0 && (
          <div className="space-y-4">
            {faq.map((item, index) => (
              <div key={index} className="border rounded-lg p-4 space-y-3 bg-gray-50">
                <div className="flex justify-between items-start">
                  <Label className="text-sm font-medium">Question {index + 1}</Label>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => removeFAQItem(index)}
                    disabled={disabled}
                  >
                    <X className="h-4 w-4" />
                  </Button>
                </div>
                <Input
                  value={item.question}
                  onChange={e => updateFAQItem(index, 'question', e.target.value)}
                  disabled={disabled}
                  placeholder="e.g., How do I reset my password?"
                />
                <div>
                  <Label className="text-sm font-medium">Answer</Label>
                  <Textarea
                    value={item.answer}
                    onChange={e => updateFAQItem(index, 'answer', e.target.value)}
                    disabled={disabled}
                    placeholder="Provide a clear, helpful answer..."
                    rows={3}
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Add new FAQ */}
        {isAdding ? (
          <div className="border rounded-lg p-4 space-y-3 bg-blue-50">
            <Label className="text-sm font-medium">New FAQ Item</Label>
            <Input
              value={newQuestion}
              onChange={e => setNewQuestion(e.target.value)}
              placeholder="Question: e.g., How do I reset my password?"
              disabled={disabled}
            />
            <div>
              <Label className="text-sm font-medium">Answer</Label>
              <Textarea
                value={newAnswer}
                onChange={e => setNewAnswer(e.target.value)}
                placeholder="Provide a clear, helpful answer..."
                disabled={disabled}
                rows={3}
              />
            </div>
            <div className="flex gap-2">
              <Button
                onClick={addFAQItem}
                disabled={!newQuestion.trim() || !newAnswer.trim() || disabled}
                size="sm"
              >
                Add FAQ
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setIsAdding(false);
                  setNewQuestion('');
                  setNewAnswer('');
                }}
                size="sm"
              >
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <Button
            onClick={() => setIsAdding(true)}
            disabled={disabled}
            variant="outline"
            className="w-full"
          >
            <Plus className="h-4 w-4 mr-2" />
            Add New FAQ Item
          </Button>
        )}

        {faq.length === 0 && !isAdding && (
          <p className="text-sm text-gray-500 text-center py-4">
            No FAQ items yet. Add your first question to enable AI auto-responses.
          </p>
        )}

        {/* Help text */}
        <div className="text-xs text-gray-500 space-y-1 bg-yellow-50 p-3 rounded-md">
          <p className="font-medium">💡 How it works:</p>
          <p>• When users ask questions, the AI matches them to your FAQ</p>
          <p>• If a match is found, an automatic response is sent instantly</p>
          <p>• This saves you time on common questions</p>
          <p>• Make sure your answers are clear and complete</p>
        </div>
      </CardContent>
    </Card>
  );
}

