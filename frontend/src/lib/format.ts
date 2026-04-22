export function formatTimestamp(value: string): string {
  return new Intl.DateTimeFormat('ko-KR', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value));
}

export function initialLabel(value?: string | null): string {
  const trimmed = value?.trim() ?? '';
  return trimmed ? trimmed[0].toUpperCase() : '?';
}
