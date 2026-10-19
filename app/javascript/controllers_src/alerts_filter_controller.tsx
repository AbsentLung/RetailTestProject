import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import { useEffect, useState } from "react"

// Mounts a React-rendered replacement for the alerts filter/table/pagination
// over the server-rendered version already in the DOM. The server-rendered
// markup (a real <form>, real links, a <noscript> submit button) is the
// no-JS fallback and stays exactly as it is; this only replaces it once JS
// has actually run.
export default class extends Controller {
  root: Root | null = null

  connect() {
    this.root = createRoot(this.element)
    this.root.render(<AlertsFilters />)
  }

  disconnect() {
    this.root?.unmount()
    this.root = null
  }
}

interface NamedRecord {
  id: number
  name: string
}

interface AlertRow {
  id: number
  brand: NamedRecord
  product: NamedRecord
  store: { id: number; address: string }
  triggered_at: string
  resolved_at: string | null
}

interface AlertsResponse {
  alerts: AlertRow[]
  brands: NamedRecord[]
  sort: string
  direction: "asc" | "desc"
  next_cursor: string | null
  prev_cursor: string | null
}

const SORT_COLUMNS: { key: string; label: string; defaultDirection: "asc" | "desc" }[] = [
  { key: "brand", label: "Brand", defaultDirection: "asc" },
  { key: "product", label: "Product", defaultDirection: "asc" },
  { key: "store", label: "Store", defaultDirection: "asc" },
  { key: "triggered_at", label: "Triggered", defaultDirection: "desc" },
  { key: "status", label: "Status", defaultDirection: "asc" },
]
const DEFAULT_SORT = "triggered_at"
const DEFAULT_DIRECTION: "asc" | "desc" = "desc"

function buildQuery(params: Record<string, string | null | undefined>): URLSearchParams {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value) query.set(key, value)
  }
  return query
}

function formatDate(iso: string): string {
  return iso.slice(0, 10)
}

function StatusPill({ resolvedAt }: { resolvedAt: string | null }) {
  if (resolvedAt) {
    return <span className="pill pill-resolved">Resolved {formatDate(resolvedAt)}</span>
  }
  return <span className="pill pill-open">Ongoing</span>
}

type LoadOverrides = Partial<{
  status: string
  brandId: string
  sort: string
  direction: "asc" | "desc"
  after: string
  before: string
}>

function AlertsFilters() {
  const [status, setStatus] = useState("")
  const [brandId, setBrandId] = useState("")
  const [sort, setSort] = useState(DEFAULT_SORT)
  const [direction, setDirection] = useState<"asc" | "desc">(DEFAULT_DIRECTION)
  const [rows, setRows] = useState<AlertRow[]>([])
  const [brands, setBrands] = useState<NamedRecord[]>([])
  const [nextCursor, setNextCursor] = useState<string | null>(null)
  const [prevCursor, setPrevCursor] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  async function load(overrides: LoadOverrides = {}, { push = true }: { push?: boolean } = {}) {
    const nextStatus = overrides.status ?? status
    const nextBrandId = overrides.brandId ?? brandId
    const nextSort = overrides.sort ?? sort
    const nextDirection = overrides.direction ?? direction

    setLoading(true)
    const query = buildQuery({
      status: nextStatus,
      brand_id: nextBrandId,
      sort: nextSort,
      direction: nextDirection,
      after: overrides.after,
      before: overrides.before,
    })

    const response = await fetch(`/alerts.json?${query.toString()}`, { headers: { Accept: "application/json" } })
    const data: AlertsResponse = await response.json()

    setStatus(nextStatus)
    setBrandId(nextBrandId)
    setSort(nextSort)
    setDirection(nextDirection)
    setRows(data.alerts)
    setBrands(data.brands)
    setNextCursor(data.next_cursor)
    setPrevCursor(data.prev_cursor)
    setLoading(false)

    // Pushing is skipped when responding to a popstate below - the browser
    // already navigated there; pushing again would add a duplicate entry
    // and Forward would never get past it.
    if (push) {
      const queryString = query.toString()
      history.pushState({}, "", queryString ? `/alerts?${queryString}` : "/alerts")
    }
  }

  useEffect(() => {
    load()
    // Runs once on mount, reading the URL this page was actually loaded
    // with isn't needed here - the no-JS version already showed that page;
    // this is what takes over once React has actually mounted.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    function handlePopState() {
      const params = new URLSearchParams(window.location.search)
      load(
        {
          status: params.get("status") ?? "",
          brandId: params.get("brand_id") ?? "",
          sort: params.get("sort") ?? DEFAULT_SORT,
          direction: (params.get("direction") as "asc" | "desc" | null) ?? DEFAULT_DIRECTION,
          after: params.get("after") ?? undefined,
          before: params.get("before") ?? undefined,
        },
        { push: false },
      )
    }
    window.addEventListener("popstate", handlePopState)
    return () => window.removeEventListener("popstate", handlePopState)
    // Every field above comes from the popstate event itself, not from
    // closed-over state, so the empty deps array (and the resulting stale
    // `load` closure from the first render) is safe here.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function handleSort(key: string, defaultDirection: "asc" | "desc") {
    const newDirection = sort === key ? (direction === "asc" ? "desc" : "asc") : defaultDirection
    load({ sort: key, direction: newDirection, after: undefined, before: undefined })
  }

  const exportHref = `/alerts.csv?${buildQuery({ status, brand_id: brandId, sort, direction }).toString()}`

  return (
    <>
      <div className="page-header">
        <h1>Alerts</h1>
        <a className="nav-link" href={exportHref}>Export CSV</a>
      </div>

      <div className="card">
        <div className="filter-row">
          <div className="filter-field">
            <label htmlFor="status">Status</label>
            <select
              id="status"
              value={status}
              onChange={(e) => load({ status: e.target.value, after: undefined, before: undefined })}
            >
              <option value="">All</option>
              <option value="open">Open</option>
              <option value="resolved">Resolved</option>
            </select>
          </div>
          <div className="filter-field">
            <label htmlFor="brand_id">Brand</label>
            <select
              id="brand_id"
              value={brandId}
              onChange={(e) => load({ brandId: e.target.value, after: undefined, before: undefined })}
            >
              <option value="">All brands</option>
              {brands.map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>
          {(status || brandId) && (
            <a
              className="nav-link"
              href="/alerts"
              onClick={(e) => {
                e.preventDefault()
                load({ status: "", brandId: "", sort: DEFAULT_SORT, direction: DEFAULT_DIRECTION, after: undefined, before: undefined })
              }}
            >
              Clear filters
            </a>
          )}
        </div>
      </div>

      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                {SORT_COLUMNS.map((col) => (
                  <th key={col.key}>
                    <a
                      className="sort-link"
                      href="#"
                      onClick={(e) => {
                        e.preventDefault()
                        handleSort(col.key, col.defaultDirection)
                      }}
                    >
                      {col.label}
                      {sort === col.key ? ` ${direction === "asc" ? "▲" : "▼"}` : ""}
                    </a>
                  </th>
                ))}
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((alert) => (
                <tr key={alert.id}>
                  <td><a href={`/brands/${alert.brand.id}`}>{alert.brand.name}</a></td>
                  <td><a href={`/products/${alert.product.id}`}>{alert.product.name}</a></td>
                  <td><a href={`/stores/${alert.store.id}`}>{alert.store.address}</a></td>
                  <td>{formatDate(alert.triggered_at)}</td>
                  <td><StatusPill resolvedAt={alert.resolved_at} /></td>
                  <td><a href={`/alerts/${alert.id}`}>View</a></td>
                </tr>
              ))}
            </tbody>
          </table>
          {!loading && rows.length === 0 && <p className="empty-state">No alerts match these filters.</p>}
        </div>
        {(prevCursor || nextCursor) && (
          <nav className="pagination">
            {prevCursor && (
              <a href="#" onClick={(e) => { e.preventDefault(); load({ before: prevCursor, after: undefined }) }}>
                &laquo; Previous
              </a>
            )}
            {nextCursor && (
              <a href="#" onClick={(e) => { e.preventDefault(); load({ after: nextCursor, before: undefined }) }}>
                Next &raquo;
              </a>
            )}
          </nav>
        )}
      </div>
    </>
  )
}
