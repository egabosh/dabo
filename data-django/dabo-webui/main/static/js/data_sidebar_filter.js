/**
 * Data Sidebar Filter
 * 
 * Provides search functionality for the data overview sidebar:
 *   - Filters list items based on search term
 *   - Expands all accordions when searching
 *   - Hides empty sections automatically
 */

(function() {
    'use strict';

    document.addEventListener('DOMContentLoaded', function() {
        const searchInput = document.getElementById('data-search');
        if (!searchInput) return;

        searchInput.addEventListener('input', function() {
            const term = this.value.toLowerCase().trim();

            // Expand all accordions when searching
            if (term.length > 0) {
                document.querySelectorAll('.accordion-collapse').forEach(el => {
                    el.classList.add('show');
                });
                document.querySelectorAll('.accordion-button').forEach(el => {
                    el.classList.remove('collapsed');
                });
            }

            // Filter list items
            document.querySelectorAll('.data-list li').forEach(li => {
                const text = li.textContent.toLowerCase();
                li.style.display = (term.length === 0 || text.includes(term)) ? '' : 'none';
            });

            // Hide empty sections
            document.querySelectorAll('.accordion-body').forEach(body => {
                const visibleItems = body.querySelectorAll('li:not([style*="display: none"])');
                const section = body.closest('.accordion-item');
                if (section) {
                    section.style.display = visibleItems.length > 0 ? '' : 'none';
                }
            });
        });
    });

})();
