export default function StatCard({ emoji, label, value, sub, color = '#7C3AED', trend }) {
  return (
    <div className="glass-card p-5 hover:bg-white/8 transition-all duration-200 group relative overflow-hidden">
      {/* Glow */}
      <div className="absolute top-0 right-0 w-20 h-20 rounded-full opacity-10 blur-xl pointer-events-none"
        style={{ background: color, transform: 'translate(30%, -30%)' }} />

      <div className="flex items-start justify-between mb-3">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl"
          style={{ background: `${color}22`, border: `1px solid ${color}44` }}>
          {emoji}
        </div>
        {trend !== undefined && (
          <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${trend >= 0 ? 'bg-green-500/15 text-green-400' : 'bg-red-500/15 text-red-400'}`}>
            {trend >= 0 ? '▲' : '▼'} {Math.abs(trend)}%
          </span>
        )}
      </div>

      <p className="text-3xl font-extrabold text-white mb-1 font-mono">
        {value ?? <span className="text-white/20">—</span>}
      </p>
      <p className="text-white/50 text-xs font-semibold uppercase tracking-wider">{label}</p>
      {sub && <p className="text-white/30 text-xs mt-1">{sub}</p>}
    </div>
  )
}
