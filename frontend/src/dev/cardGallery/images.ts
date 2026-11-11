/**
 * Local stand-ins for the server's pictures, so the gallery never asks the network for one. Inline
 * SVG as `data:` URLs: they carry no `{size}` token, so `sizedUrl`/`widthSrcSet` leave them as they
 * are, and percent-encoding keeps the commas of a raw SVG out of a `srcSet`.
 */

function svg(width: number, height: number, body: string): string {
  const markup = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(markup)}`
}

/** A landscape photo: sky, two ridges, a road. */
export const PHOTO_URL = svg(
  800,
  450,
  `<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9cc3e6"/><stop offset="1" stop-color="#e8eef4"/></linearGradient></defs>
  <rect width="800" height="450" fill="url(#s)"/>
  <path d="M0 290 L140 190 L260 260 L400 150 L560 250 L680 180 L800 240 L800 450 L0 450 Z" fill="#6f8f6a"/>
  <path d="M0 350 L180 280 L330 330 L520 270 L800 330 L800 450 L0 450 Z" fill="#4e6e4b"/>
  <path d="M330 450 C380 400 420 380 470 330" stroke="#d9d4c7" stroke-width="18" fill="none"/>`
)

/** A route map preview, light basemap. */
export const MAP_LIGHT_URL = svg(
  256,
  256,
  `<rect width="256" height="256" fill="#f1efe9"/>
  <path d="M0 80 H256 M0 170 H256 M70 0 V256 M190 0 V256" stroke="#e2ded4" stroke-width="6"/>
  <path d="M60 200 C40 140 80 70 140 60 C200 50 220 120 190 170 C160 220 100 230 60 200 Z" stroke="#4c6ef5" stroke-width="7" fill="none" stroke-linejoin="round"/>
  <circle cx="60" cy="200" r="9" fill="#2f9e44"/>`
)

/** The same preview on a dark basemap. */
export const MAP_DARK_URL = svg(
  256,
  256,
  `<rect width="256" height="256" fill="#25262b"/>
  <path d="M0 80 H256 M0 170 H256 M70 0 V256 M190 0 V256" stroke="#373a40" stroke-width="6"/>
  <path d="M60 200 C40 140 80 70 140 60 C200 50 220 120 190 170 C160 220 100 230 60 200 Z" stroke="#91a7ff" stroke-width="7" fill="none" stroke-linejoin="round"/>
  <circle cx="60" cy="200" r="9" fill="#51cf66"/>`
)
