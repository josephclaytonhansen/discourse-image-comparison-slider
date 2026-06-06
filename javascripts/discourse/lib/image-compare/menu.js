export const MENU_PADDING = 8;

export function settingsMenuOptions({
  identifier,
  component,
  data,
  portalOutletElement,
}) {
  return {
    identifier,
    component,
    data,
    portalOutletElement,
    closeOnClickOutside: false,
    closeOnEscape: false,
    closeOnScroll: false,
    padding: MENU_PADDING,
    trapTab: false,
    placement: "top",
    fallbackPlacements: ["top"],
    modalForMobile: false,
    offset({ rects }) {
      return {
        mainAxis: -MENU_PADDING - rects.floating.height,
      };
    },
    limitShift: {
      offset: ({ rects, placement }) => ({
        crossAxis:
          (-rects.floating.height - MENU_PADDING) *
          (placement.includes("top") ? -1 : 1),
      }),
    },
  };
}
