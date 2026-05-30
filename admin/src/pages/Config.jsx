import { useEffect, useState } from 'react'
import { ref, onValue, set, update, push } from 'firebase/database'
import { db } from '../firebase'
import { Save, ToggleLeft, ToggleRight, Upload, Loader, CheckCircle } from 'lucide-react'

const FIELDS = [
  { key:'latestVersion',    label:'Latest Version',       type:'text',   placeholder:'1.0.0',     group:'update' },
  { key:'updateUrl',        label:'APK Download URL',     type:'url',    placeholder:'https://…', group:'update' },
  { key:'forceUpdate',      label:'Force Update',         type:'bool',   group:'update' },
  { key:'updateMessage',    label:'Update Message',       type:'text',   placeholder:'A new version is available!', group:'update' },
  { key:'changelog',        label:'Changelog',            type:'textarea',placeholder:'What\'s new…', group:'update' },
  { key:'maintenanceMode',  label:'Maintenance Mode',     type:'bool',   group:'feature' },
  { key:'chatEnabled',      label:'Chat Enabled',         type:'bool',   group:'feature' },
  { key:'gamesEnabled',     label:'Games Enabled',        type:'bool',   group:'feature' },
  { key:'maxStoryDuration', label:'Max Story Duration (s)',type:'number', placeholder:'60',        group:'feature' },
]

async function logAction(msg) {
  await push(ref(db, 'adminLogs'), { action:'CONFIG_UPDATED', emoji:'⚙️', message: msg, timestamp: Date.now() })
}

export default function Config() {
  const [config, setConfig] = useState({})
  const [saving, setSaving] = useState({})
  const [saved, setSaved]   = useState({})

  useEffect(() => {
    const unsub = onValue(ref(db, 'appConfig'), snap => {
      setConfig(snap.exists() ? snap.val() : {})
    })
    return unsub
  }, [])

  const saveField = async (key, value) => {
    setSaving(s => ({ ...s, [key]: true }))
    await set(ref(db, `appConfig/${key}`), value)
    await logAction(`Updated ${key}: ${value}`)
    setSaving(s => ({ ...s, [key]: false }))
    setSaved(s => ({ ...s, [key]: true }))
    setTimeout(() => setSaved(s => ({ ...s, [key]: false })), 2000)
  }

  const toggleBool = (key) => saveField(key, !config[key])

  const renderField = (f) => {
    if (f.type === 'bool') return (
      <div key={f.key} className="glass-card p-4 flex items-center justify-between">
        <div>
          <p className="text-white font-semibold text-sm">{f.label}</p>
          <p className="text-white/30 text-xs mt-0.5">Firebase: appConfig/{f.key}</p>
        </div>
        <button onClick={() => toggleBool(f.key)}
          className={`w-12 h-6 rounded-full relative transition-all duration-300 ${config[f.key] ? 'bg-primary' : 'bg-white/10'}`}>
          <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-all duration-300 ${config[f.key] ? 'left-6' : 'left-0.5'}`} />
        </button>
      </div>
    )

    return (
      <div key={f.key} className="glass-card p-4 space-y-2">
        <div className="flex items-center justify-between">
          <label className="text-white font-semibold text-sm">{f.label}</label>
          <span className="text-white/20 text-xs font-mono">appConfig/{f.key}</span>
        </div>
        {f.type === 'textarea'
          ? <textarea rows={3} value={config[f.key] || ''} onChange={e => setConfig(c => ({...c, [f.key]: e.target.value}))}
              placeholder={f.placeholder} className="input-field resize-none text-sm"/>
          : <input type={f.type === 'url' ? 'url' : f.type === 'number' ? 'number' : 'text'}
              value={config[f.key] || ''} onChange={e => setConfig(c => ({...c, [f.key]: f.type==='number' ? Number(e.target.value) : e.target.value}))}
              placeholder={f.placeholder} className="input-field text-sm"/>
        }
        <button onClick={() => saveField(f.key, config[f.key])} disabled={saving[f.key]}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${saved[f.key] ? 'bg-green-500/15 text-green-400 border border-green-500/20' : 'btn-primary'}`}>
          {saving[f.key] ? <Loader size={11} className="animate-spin"/> : saved[f.key] ? <CheckCircle size={11}/> : <Save size={11}/>}
          {saving[f.key] ? 'Saving…' : saved[f.key] ? 'Saved!' : 'Save'}
        </button>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-2 gap-6">
      {/* Update Config */}
      <div className="space-y-3">
        <h2 className="section-title">📦 Update Manager</h2>
        {FIELDS.filter(f => f.group === 'update').map(renderField)}

        <button onClick={async () => {
          const { latestVersion, updateUrl, updateMessage, forceUpdate, changelog } = config
          await update(ref(db, 'appConfig'), { latestVersion, updateUrl, updateMessage, forceUpdate: !!forceUpdate, changelog })
          await logAction(`Published update v${latestVersion}`)
        }} className="w-full btn-primary py-3 justify-center gap-2">
          <Upload size={15}/> Publish Update to All Users
        </button>
      </div>

      {/* Feature Flags */}
      <div className="space-y-3">
        <h2 className="section-title">🎛️ Feature Flags</h2>
        {FIELDS.filter(f => f.group === 'feature').map(renderField)}

        <div className="glass-card p-5 mt-2">
          <h3 className="text-white font-semibold text-sm mb-3">📊 Current Config</h3>
          <pre className="text-xs font-mono text-green-300/80 overflow-x-auto leading-relaxed"
            style={{ maxHeight: 180 }}>
            {JSON.stringify(config, null, 2)}
          </pre>
        </div>
      </div>
    </div>
  )
}
