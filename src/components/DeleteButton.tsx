"use client";

export default function DeleteButton({
  label,
  confirmText,
  className = "text-sm font-semibold text-red-600",
}: {
  label: string;
  confirmText: string;
  className?: string;
}) {
  return (
    <button
      type="submit"
      className={className}
      onClick={(e) => {
        if (!window.confirm(confirmText)) e.preventDefault();
      }}
    >
      {label}
    </button>
  );
}
