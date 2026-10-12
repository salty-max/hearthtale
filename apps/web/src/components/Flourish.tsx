/** An ornament between a title and its text: a gold rule with a diamond at its heart. */
export function Flourish({ className = "" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 240 16" className={`mx-auto h-4 w-48 max-w-full ${className}`} fill="currentColor">
      <path d="M8 7.5h84v1H8z" opacity=".55" />
      <path d="M148 7.5h84v1h-84z" opacity=".55" />
      <circle cx="96" cy="8" r="1.5" />
      <circle cx="144" cy="8" r="1.5" />
      <path d="M104 8l4-3.5 4 3.5-4 3.5z" opacity=".75" />
      <path d="M128 8l4-3.5 4 3.5-4 3.5z" opacity=".75" />
      <path d="M120 1.5l6.5 6.5-6.5 6.5-6.5-6.5z" />
    </svg>
  );
}
