import { ref } from 'vue';
import {
  useContactSidebarResize,
  MIN_CONTACT_SIDEBAR_WIDTH,
  DEFAULT_CONTACT_SIDEBAR_WIDTH,
  DEFAULT_CONTACT_SIDEBAR_WIDTH_2XL,
  MAX_CONTACT_SIDEBAR_WIDTH,
} from '../useContactSidebarResize';

const mockUpdateUISettings = vi.fn();
const mockUISettings = ref({});
const mockIsRTL = ref(false);

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: mockUISettings,
    updateUISettings: mockUpdateUISettings,
  }),
}));

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => mockIsRTL,
}));

describe('useContactSidebarResize', () => {
  beforeEach(() => {
    mockUpdateUISettings.mockClear();
    mockUISettings.value = {};
    mockIsRTL.value = false;
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 1400,
    });
  });

  it('initializes with default width when uiSettings has no width', () => {
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(DEFAULT_CONTACT_SIDEBAR_WIDTH);
  });

  it('initializes with 2XL default width when window is >= 1536px', () => {
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 1600,
    });
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(DEFAULT_CONTACT_SIDEBAR_WIDTH_2XL);
  });

  it('initializes with saved width when uiSettings has valid width', () => {
    mockUISettings.value = { contact_sidebar_width: 420 };
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(420);
  });

  it('clamps saved width if below MIN_CONTACT_SIDEBAR_WIDTH', () => {
    mockUISettings.value = { contact_sidebar_width: 250 };
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(MIN_CONTACT_SIDEBAR_WIDTH);
  });

  it('clamps saved width if above max ratio width', () => {
    // window.innerWidth = 1400 => max is 45% of 1400 = 630
    mockUISettings.value = { contact_sidebar_width: 750 };
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(630);
  });

  it('clamps saved width if above MAX_CONTACT_SIDEBAR_WIDTH on large screen', () => {
    // window.innerWidth = 2000 => 45% = 900, but capped at MAX_CONTACT_SIDEBAR_WIDTH (700)
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 2000,
    });
    mockUISettings.value = { contact_sidebar_width: 800 };
    const { contactSidebarWidth } = useContactSidebarResize();
    expect(contactSidebarWidth.value).toBe(MAX_CONTACT_SIDEBAR_WIDTH);
  });

  it('updates width during drag in LTR (dragging left expands) and saves on resize end', () => {
    const { contactSidebarWidth, onResizeStart, isResizing } =
      useContactSidebarResize();

    onResizeStart({
      clientX: 1000,
      preventDefault: vi.fn(),
    });
    expect(isResizing.value).toBe(true);

    // In LTR: dragging cursor to the left (1000 -> 920 = 80px expansion)
    document.dispatchEvent(new MouseEvent('mousemove', { clientX: 920 }));
    // Initial default 320 + 80 = 400
    expect(contactSidebarWidth.value).toBe(400);

    // Simulate mouse up
    document.dispatchEvent(new MouseEvent('mouseup'));
    expect(isResizing.value).toBe(false);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      contact_sidebar_width: 400,
    });
  });

  it('inverts delta during drag in RTL mode (dragging right expands)', () => {
    mockIsRTL.value = true;
    const { contactSidebarWidth, onResizeStart } = useContactSidebarResize();

    onResizeStart({
      clientX: 400,
      preventDefault: vi.fn(),
    });

    // In RTL: dragging cursor to the right (400 -> 480 = 80px expansion)
    document.dispatchEvent(new MouseEvent('mousemove', { clientX: 480 }));
    // Initial default 320 + 80 = 400
    expect(contactSidebarWidth.value).toBe(400);

    document.dispatchEvent(new MouseEvent('mouseup'));
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      contact_sidebar_width: 400,
    });
  });

  it('resets to default width on double-click and persists', () => {
    mockUISettings.value = { contact_sidebar_width: 500 };
    const { contactSidebarWidth, onResizeHandleDoubleClick } =
      useContactSidebarResize();

    expect(contactSidebarWidth.value).toBe(500);

    onResizeHandleDoubleClick();
    expect(contactSidebarWidth.value).toBe(DEFAULT_CONTACT_SIDEBAR_WIDTH);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      contact_sidebar_width: DEFAULT_CONTACT_SIDEBAR_WIDTH,
    });
  });
});
