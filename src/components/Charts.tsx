"use client";

/** Tiny dependency-free SVG charts. */

export function BarChart({
  data,
  height = 140,
  color = "#1d6fd1",
}: {
  data: { label: string; value: number }[];
  height?: number;
  color?: string;
}) {
  const max = Math.max(100, ...data.map((d) => d.value));
  const w = Math.max(data.length * 34, 120);
  const bw = Math.min(22, (w / Math.max(data.length, 1)) * 0.55);
  return (
    <div className="overflow-x-auto" dir="ltr">
      <svg width={w} height={height + 22} role="img" aria-label="bar chart">
        {data.map((d, i) => {
          const h = Math.max(2, (d.value / max) * height);
          const x = i * (w / data.length) + (w / data.length - bw) / 2;
          return (
            <g key={i}>
              <rect x={x} y={height - h} width={bw} height={h} rx={4} fill={color} opacity={0.9} />
              <text x={x + bw / 2} y={height + 14} textAnchor="middle" fontSize={9} fill="#94a3b8">
                {d.label}
              </text>
              <text x={x + bw / 2} y={height - h - 4} textAnchor="middle" fontSize={9} fill="#475569">
                {Math.round(d.value)}%
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}

export function DonutChart({
  parts,
  size = 140,
  label,
}: {
  parts: { value: number; color: string; label: string }[];
  size?: number;
  label?: string;
}) {
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  const r = size / 2 - 12;
  const c = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div className="flex items-center gap-4">
      <svg width={size} height={size} role="img" aria-label="donut chart">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#e2e8f0" strokeWidth={18} />
        {parts.map((p, i) => {
          const frac = p.value / total;
          const el = (
            <circle
              key={i}
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke={p.color}
              strokeWidth={18}
              strokeDasharray={`${frac * c} ${c}`}
              strokeDashoffset={-offset * c}
              transform={`rotate(-90 ${size / 2} ${size / 2})`}
              strokeLinecap="butt"
            />
          );
          offset += frac;
          return el;
        })}
        <text x={size / 2} y={size / 2 - 2} textAnchor="middle" fontSize={15} fontWeight={700} fill="#0f172a">
          {label ?? `${Math.round((parts[0]?.value / total) * 100)}%`}
        </text>
      </svg>
      <ul className="space-y-1 text-xs text-slate-600">
        {parts.map((p, i) => (
          <li key={i} className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm" style={{ background: p.color }} />
            {p.label}: {p.value.toLocaleString()}
          </li>
        ))}
      </ul>
    </div>
  );
}
