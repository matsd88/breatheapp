// FAQ Accordion
document.querySelectorAll('.faq-q').forEach(btn => {
    btn.addEventListener('click', () => {
        const item = btn.parentElement;
        const wasOpen = item.classList.contains('open');
        // Close all
        document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));
        // Toggle clicked
        if (!wasOpen) item.classList.add('open');
    });
});

// Scroll reveal
const reveals = document.querySelectorAll('.reveal');
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
        }
    });
}, { threshold: 0.15 });

reveals.forEach(el => observer.observe(el));
