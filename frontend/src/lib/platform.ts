/** Apple desktop or tablet: the shortcuts there use ⌘ and ⌥ where others use Ctrl and Alt. */
export function isApplePlatform(): boolean {
  if (typeof navigator === 'undefined') return false
  const nav = navigator as Navigator & { userAgentData?: { platform?: string } }
  const platform = nav.userAgentData?.platform ?? navigator.userAgent
  return /Mac|iPhone|iPad|iPod/i.test(platform)
}
