document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('data-search');
    if (!searchInput) return;
    
    searchInput.addEventListener('input', function() {
        const term = this.value.toLowerCase();
        document.querySelectorAll('.data-list li').forEach(li => {
            const text = li.textContent.toLowerCase();
            li.style.display = text.includes(term) ? '' : 'none';
        });
    });
});

