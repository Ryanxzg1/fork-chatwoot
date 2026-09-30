import { ref } from 'vue';
import {
  useChatListResize,
  MIN_CHAT_LIST_WIDTH,
  DEFAULT_CHAT_LIST_WIDTH,
} from '../useChatListResize';

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

describe('useChatListResize', () => {
  beforeEach(() => {
    mockUpdateUISettings.mockClear();
    mockUISettings.value = {};
    mockIsRTL.value = false;
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 1200,
    });
  });

  it('initializes with default width when uiSettings has no width', () => {
    const { chatListWidth } = useChatListResize();
    expect(chatListWidth.value).toBe(DEFAULT_CHAT_LIST_WIDTH);
  });

  it('initializes with saved width when uiSettings has valid width', () => {
    mockUISettings.value = { conversation_list_width: 450 };
    const { chatListWidth } = useChatListResize();
    expect(chatListWidth.value).toBe(450);
  });

  it('clamps saved width if below MIN_CHAT_LIST_WIDTH', () => {
    mockUISettings.value = { conversation_list_width: 200 };
    const { chatListWidth } = useChatListResize();
    expect(chatListWidth.value).toBe(MIN_CHAT_LIST_WIDTH);
  });

  it('clamps saved width if above 50% screen width', () => {
    // window.innerWidth = 1200 => max is 600
    mockUISettings.value = { conversation_list_width: 800 };
    const { chatListWidth } = useChatListResize();
    expect(chatListWidth.value).toBe(600);
  });

  it('updates width during drag in LTR and saves on resize end', () => {
    const { chatListWidth, onResizeStart, isResizing } = useChatListResize();

    onResizeStart({
      clientX: 410,
      preventDefault: vi.fn(),
    });
    expect(isResizing.value).toBe(true);

    // Simulate mouse move to right (+60px)
    document.dispatchEvent(new MouseEvent('mousemove', { clientX: 470 }));
    expect(chatListWidth.value).toBe(470);

    // Simulate mouse up
    document.dispatchEvent(new MouseEvent('mouseup'));
    expect(isResizing.value).toBe(false);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_list_width: 470,
    });
  });

  it('inverts delta during drag in RTL mode', () => {
    mockIsRTL.value = true;
    const { chatListWidth, onResizeStart } = useChatListResize();

    onResizeStart({
      clientX: 500,
      preventDefault: vi.fn(),
    });

    // In RTL, dragging mouse to the left (decreasing clientX) expands width (+50px)
    document.dispatchEvent(new MouseEvent('mousemove', { clientX: 450 }));
    expect(chatListWidth.value).toBe(460);

    document.dispatchEvent(new MouseEvent('mouseup'));
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_list_width: 460,
    });
  });

  it('resets to default width on double-click and persists', () => {
    mockUISettings.value = { conversation_list_width: 500 };
    const { chatListWidth, onResizeHandleDoubleClick } = useChatListResize();

    expect(chatListWidth.value).toBe(500);

    onResizeHandleDoubleClick();
    expect(chatListWidth.value).toBe(DEFAULT_CHAT_LIST_WIDTH);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_list_width: DEFAULT_CHAT_LIST_WIDTH,
    });
  });
});
