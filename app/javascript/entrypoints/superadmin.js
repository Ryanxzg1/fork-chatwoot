import '../dashboard/assets/scss/super_admin/index.scss';

const initializeAccountSuspensionForm = () => {
  const form = document.querySelector('[data-account-suspension-form]');
  if (!form) return;

  const status = form.querySelector('[data-account-status-select]');
  const fields = form.querySelector('[data-account-suspension-fields]');
  if (!status || !fields) return;

  const category = fields.querySelector('[data-suspension-category]');
  const reason = fields.querySelector('[data-suspension-reason]');
  const controls = [category, reason];
  const originalStatus = form.dataset.originalStatus;
  const hasHistory = form.dataset.hasSuspensionHistory === 'true';

  const updateFields = () => {
    const isSuspended = status.value === 'suspended';
    const hasEnteredDetails = controls.some(
      control => control.value.trim().length > 0
    );
    const detailsRequired =
      isSuspended &&
      (originalStatus === 'active' || hasHistory || hasEnteredDetails);

    fields.classList.toggle('hidden', !isSuspended);
    controls.forEach(control => {
      control.disabled = !isSuspended;
      control.required = detailsRequired;
    });
  };

  status.addEventListener('change', updateFields);
  controls.forEach(control => control.addEventListener('input', updateFields));
  updateFields();
};

const showToast = (message, type = 'success') => {
  let toastContainer = document.getElementById('superadmin-toast-container');
  if (!toastContainer) {
    toastContainer = document.createElement('div');
    toastContainer.id = 'superadmin-toast-container';
    toastContainer.className =
      'fixed top-5 right-5 z-50 flex flex-col gap-2 pointer-events-none';
    document.body.appendChild(toastContainer);
  }

  const toast = document.createElement('div');
  const bgClass =
    type === 'success'
      ? 'bg-emerald-600 text-white shadow-emerald-900/20'
      : 'bg-red-600 text-white shadow-red-900/20';
  toast.className = `${bgClass} px-4 py-3 rounded-lg shadow-lg text-sm font-medium flex items-center gap-2 transform transition-all duration-300 ease-out -translate-y-2 opacity-0 pointer-events-auto max-w-sm`;

  const iconSvg =
    type === 'success'
      ? '<svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>'
      : '<svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>';

  toast.innerHTML = `${iconSvg}<span>${message}</span>`;
  toastContainer.appendChild(toast);

  requestAnimationFrame(() => {
    toast.classList.remove('-translate-y-2', 'opacity-0');
    toast.classList.add('translate-y-0', 'opacity-100');
  });

  setTimeout(() => {
    toast.classList.remove('translate-y-0', 'opacity-100');
    toast.classList.add('-translate-y-2', 'opacity-0');
    setTimeout(() => toast.remove(), 300);
  }, 3500);
};

const initializeAjaxDestroy = () => {
  document.addEventListener(
    'click',
    async event => {
      const link = event.target.closest(
        'a[data-method="delete"], a.remove-attachment-link'
      );
      if (!link) return;

      const confirmMessage = link.dataset.confirm || link.dataset.turboConfirm;
      if (confirmMessage) {
        // eslint-disable-next-line no-alert
        if (!window.confirm(confirmMessage)) {
          event.preventDefault();
          event.stopImmediatePropagation();
          return;
        }
      }

      event.preventDefault();
      event.stopImmediatePropagation();

      const csrfToken = document.querySelector(
        'meta[name="csrf-token"]'
      )?.content;
      const row = link.closest('tr');
      const attachmentItem =
        link.closest('.field-unit--has-one, .field-unit--avatar-field') ||
        link.closest('div');
      const isHeaderAction =
        link.closest('.main-content__header') ||
        link.classList.contains('button--danger');

      if (row) {
        row.style.transition = 'opacity 0.2s';
        row.style.opacity = '0.4';
        row.style.pointerEvents = 'none';
      } else {
        link.style.opacity = '0.5';
        link.style.pointerEvents = 'none';
      }

      try {
        const response = await fetch(link.href, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': csrfToken,
            Accept: 'application/json',
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
        });

        const data = await response.json().catch(() => ({}));

        if (response.ok && data.success !== false) {
          showToast(data.message || 'Successfully deleted', 'success');

          if (row) {
            row.style.transition = 'all 0.3s ease-out';
            row.style.opacity = '0';
            row.style.transform = 'scale(0.98)';
            setTimeout(() => {
              row.remove();
            }, 300);
          } else if (isHeaderAction) {
            setTimeout(() => {
              window.location.href = data.redirect_url || '/super_admin';
            }, 800);
          } else if (attachmentItem) {
            attachmentItem.style.transition = 'opacity 0.3s';
            attachmentItem.style.opacity = '0';
            setTimeout(() => attachmentItem.remove(), 300);
          } else {
            link.remove();
          }
        } else {
          const errorMsg = data.message || 'Failed to delete resource';
          showToast(errorMsg, 'error');
          if (row) {
            row.style.opacity = '1';
            row.style.pointerEvents = 'auto';
          } else {
            link.style.opacity = '1';
            link.style.pointerEvents = 'auto';
          }
        }
      } catch (err) {
        showToast('Network error while deleting resource', 'error');
        if (row) {
          row.style.opacity = '1';
          row.style.pointerEvents = 'auto';
        } else {
          link.style.opacity = '1';
          link.style.pointerEvents = 'auto';
        }
      }
    },
    true
  );
};

document.addEventListener('DOMContentLoaded', () => {
  initializeAccountSuspensionForm();
  initializeAjaxDestroy();
});
