import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import { Controller } from "@hotwired/stimulus";
import { createRoot } from "react-dom/client";
import { useEffect, useRef, useState } from "react";
class alerts_filter_controller_default extends Controller {
  root = null;
  connect() {
    this.root = createRoot(this.element);
    this.root.render(/* @__PURE__ */ jsx(AlertsFilters, {}));
  }
  disconnect() {
    this.root?.unmount();
    this.root = null;
  }
}
const SORT_COLUMNS = [
  { key: "brand", label: "Brand", defaultDirection: "asc" },
  { key: "product", label: "Product", defaultDirection: "asc" },
  { key: "store", label: "Store", defaultDirection: "asc" },
  { key: "triggered_at", label: "Triggered", defaultDirection: "desc" },
  { key: "status", label: "Status", defaultDirection: "asc" }
];
const DEFAULT_SORT = "triggered_at";
const DEFAULT_DIRECTION = "desc";
function buildQuery(params) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value) query.set(key, value);
  }
  return query;
}
function formatDate(iso) {
  return iso.slice(0, 10);
}
function parseOverridesFromSearch(search) {
  const params = new URLSearchParams(search);
  return {
    status: params.get("status") ?? "",
    brandId: params.get("brand_id") ?? "",
    sort: params.get("sort") ?? DEFAULT_SORT,
    direction: params.get("direction") ?? DEFAULT_DIRECTION,
    after: params.get("after") ?? void 0,
    before: params.get("before") ?? void 0
  };
}
function StatusPill({ resolvedAt }) {
  if (resolvedAt) {
    return /* @__PURE__ */ jsxs("span", { className: "pill pill-resolved", children: [
      "Resolved ",
      formatDate(resolvedAt)
    ] });
  }
  return /* @__PURE__ */ jsx("span", { className: "pill pill-open", children: "Ongoing" });
}
function AlertsFilters() {
  const [status, setStatus] = useState("");
  const [brandId, setBrandId] = useState("");
  const [sort, setSort] = useState(DEFAULT_SORT);
  const [direction, setDirection] = useState(DEFAULT_DIRECTION);
  const [rows, setRows] = useState([]);
  const [brands, setBrands] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [prevCursor, setPrevCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const currentFetch = useRef(null);
  async function load(overrides = {}, { push = true } = {}) {
    const nextStatus = overrides.status ?? status;
    const nextBrandId = overrides.brandId ?? brandId;
    const nextSort = overrides.sort ?? sort;
    const nextDirection = overrides.direction ?? direction;
    currentFetch.current?.abort();
    const controller = new AbortController();
    currentFetch.current = controller;
    setLoading(true);
    const query = buildQuery({
      status: nextStatus,
      brand_id: nextBrandId,
      sort: nextSort,
      direction: nextDirection,
      after: overrides.after,
      before: overrides.before
    });
    let response;
    try {
      response = await fetch(`/alerts.json?${query.toString()}`, {
        headers: { Accept: "application/json" },
        signal: controller.signal
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return;
      setLoading(false);
      return;
    }
    if (!response.ok) {
      setLoading(false);
      return;
    }
    const data = await response.json();
    setStatus(nextStatus);
    setBrandId(nextBrandId);
    setSort(nextSort);
    setDirection(nextDirection);
    setRows(data.alerts);
    setBrands(data.brands);
    setNextCursor(data.next_cursor);
    setPrevCursor(data.prev_cursor);
    setLoading(false);
    if (push) {
      const queryString = query.toString();
      history.pushState({}, "", queryString ? `/alerts?${queryString}` : "/alerts");
    }
  }
  useEffect(() => {
    load(parseOverridesFromSearch(window.location.search), { push: false });
  }, []);
  useEffect(() => {
    function handlePopState() {
      load(parseOverridesFromSearch(window.location.search), { push: false });
    }
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);
  function handleSort(key, defaultDirection) {
    const newDirection = sort === key ? direction === "asc" ? "desc" : "asc" : defaultDirection;
    load({ sort: key, direction: newDirection, after: void 0, before: void 0 });
  }
  const exportHref = `/alerts.csv?${buildQuery({ status, brand_id: brandId, sort, direction }).toString()}`;
  return /* @__PURE__ */ jsxs(Fragment, { children: [
    /* @__PURE__ */ jsxs("div", { className: "page-header", children: [
      /* @__PURE__ */ jsx("h1", { children: "Alerts" }),
      /* @__PURE__ */ jsx("a", { className: "nav-link", href: exportHref, children: "Export CSV" })
    ] }),
    /* @__PURE__ */ jsx("div", { className: "card", children: /* @__PURE__ */ jsxs("div", { className: "filter-row", children: [
      /* @__PURE__ */ jsxs("div", { className: "filter-field", children: [
        /* @__PURE__ */ jsx("label", { htmlFor: "status", children: "Status" }),
        /* @__PURE__ */ jsxs(
          "select",
          {
            id: "status",
            value: status,
            onChange: (e) => load({ status: e.target.value, after: void 0, before: void 0 }),
            children: [
              /* @__PURE__ */ jsx("option", { value: "", children: "All" }),
              /* @__PURE__ */ jsx("option", { value: "open", children: "Open" }),
              /* @__PURE__ */ jsx("option", { value: "resolved", children: "Resolved" })
            ]
          }
        )
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "filter-field", children: [
        /* @__PURE__ */ jsx("label", { htmlFor: "brand_id", children: "Brand" }),
        /* @__PURE__ */ jsxs(
          "select",
          {
            id: "brand_id",
            value: brandId,
            onChange: (e) => load({ brandId: e.target.value, after: void 0, before: void 0 }),
            children: [
              /* @__PURE__ */ jsx("option", { value: "", children: "All brands" }),
              brands.map((b) => /* @__PURE__ */ jsx("option", { value: String(b.id), children: b.name }, b.id))
            ]
          }
        )
      ] }),
      (status || brandId) && /* @__PURE__ */ jsx(
        "a",
        {
          className: "nav-link",
          href: "/alerts",
          onClick: (e) => {
            e.preventDefault();
            load({ status: "", brandId: "", sort: DEFAULT_SORT, direction: DEFAULT_DIRECTION, after: void 0, before: void 0 });
          },
          children: "Clear filters"
        }
      )
    ] }) }),
    /* @__PURE__ */ jsxs("div", { className: "card", children: [
      /* @__PURE__ */ jsxs("div", { className: "table-wrap", children: [
        /* @__PURE__ */ jsxs("table", { children: [
          /* @__PURE__ */ jsx("thead", { children: /* @__PURE__ */ jsxs("tr", { children: [
            SORT_COLUMNS.map((col) => /* @__PURE__ */ jsx("th", { children: /* @__PURE__ */ jsxs(
              "a",
              {
                className: "sort-link",
                href: "#",
                onClick: (e) => {
                  e.preventDefault();
                  handleSort(col.key, col.defaultDirection);
                },
                children: [
                  col.label,
                  sort === col.key ? ` ${direction === "asc" ? "\u25B2" : "\u25BC"}` : ""
                ]
              }
            ) }, col.key)),
            /* @__PURE__ */ jsx("th", {})
          ] }) }),
          /* @__PURE__ */ jsx("tbody", { children: rows.map((alert) => /* @__PURE__ */ jsxs("tr", { children: [
            /* @__PURE__ */ jsx("td", { children: /* @__PURE__ */ jsx("a", { href: `/brands/${alert.brand.id}`, children: alert.brand.name }) }),
            /* @__PURE__ */ jsx("td", { children: /* @__PURE__ */ jsx("a", { href: `/products/${alert.product.id}`, children: alert.product.name }) }),
            /* @__PURE__ */ jsx("td", { children: /* @__PURE__ */ jsx("a", { href: `/stores/${alert.store.id}`, children: alert.store.address }) }),
            /* @__PURE__ */ jsx("td", { children: formatDate(alert.triggered_at) }),
            /* @__PURE__ */ jsx("td", { children: /* @__PURE__ */ jsx(StatusPill, { resolvedAt: alert.resolved_at }) }),
            /* @__PURE__ */ jsx("td", { children: /* @__PURE__ */ jsx("a", { href: `/alerts/${alert.id}`, children: "View" }) })
          ] }, alert.id)) })
        ] }),
        !loading && rows.length === 0 && /* @__PURE__ */ jsx("p", { className: "empty-state", children: "No alerts match these filters." })
      ] }),
      (prevCursor || nextCursor) && /* @__PURE__ */ jsxs("nav", { className: "pagination", children: [
        prevCursor && /* @__PURE__ */ jsx("a", { href: "#", onClick: (e) => {
          e.preventDefault();
          load({ before: prevCursor, after: void 0 });
        }, children: "\xAB Previous" }),
        nextCursor && /* @__PURE__ */ jsx("a", { href: "#", onClick: (e) => {
          e.preventDefault();
          load({ after: nextCursor, before: void 0 });
        }, children: "Next \xBB" })
      ] })
    ] })
  ] });
}
export {
  alerts_filter_controller_default as default
};
