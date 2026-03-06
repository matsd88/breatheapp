// ========== FAQ Accordion ==========
document.querySelectorAll('.faq-q').forEach(btn => {
    btn.addEventListener('click', () => {
        const item = btn.parentElement;
        const wasOpen = item.classList.contains('open');
        document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));
        if (!wasOpen) item.classList.add('open');
    });
});

// ========== Scroll Reveal ==========
const reveals = document.querySelectorAll('.reveal');
const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry, i) => {
        if (entry.isIntersecting) {
            // Stagger siblings
            const siblings = entry.target.parentElement.querySelectorAll('.reveal');
            let delay = 0;
            siblings.forEach(sib => {
                if (sib === entry.target) {
                    entry.target.style.transitionDelay = delay + 'ms';
                }
                delay += 80;
            });
            setTimeout(() => {
                entry.target.classList.add('visible');
            }, 10);
            revealObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

reveals.forEach(el => revealObserver.observe(el));

// ========== Nav Scroll ==========
const nav = document.querySelector('.nav');
window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.scrollY > 30);
}, { passive: true });

// ========== Mobile Menu ==========
const menuBtn = document.querySelector('.nav-menu-btn');
const mobileMenu = document.querySelector('.nav-mobile');
if (menuBtn && mobileMenu) {
    menuBtn.addEventListener('click', () => {
        const isOpen = getComputedStyle(mobileMenu).display === 'flex';
        mobileMenu.style.display = isOpen ? 'none' : 'flex';
    });
    // Close on link click
    mobileMenu.querySelectorAll('a').forEach(a => {
        a.addEventListener('click', () => {
            mobileMenu.style.display = 'none';
        });
    });
}

// ========== Animated Counters ==========
const counters = document.querySelectorAll('.counter');
const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const el = entry.target;
            const target = parseFloat(el.dataset.target);
            const suffix = el.dataset.suffix || '';
            const isDecimal = target % 1 !== 0;
            const duration = 1800;
            const start = performance.now();

            function update(now) {
                const elapsed = now - start;
                const progress = Math.min(elapsed / duration, 1);
                const eased = 1 - Math.pow(1 - progress, 4);
                const current = target * eased;
                el.textContent = (isDecimal ? current.toFixed(1) : Math.round(current)) + suffix;
                if (progress < 1) requestAnimationFrame(update);
            }
            requestAnimationFrame(update);
            counterObserver.unobserve(el);
        }
    });
}, { threshold: 0.5 });

counters.forEach(el => counterObserver.observe(el));

// ========== Hero Particles ==========
const particlesContainer = document.getElementById('heroParticles');
if (particlesContainer) {
    for (let i = 0; i < 25; i++) {
        const p = document.createElement('div');
        p.className = 'hero-particle';
        p.style.left = Math.random() * 100 + '%';
        p.style.animationDuration = (10 + Math.random() * 15) + 's';
        p.style.animationDelay = (Math.random() * 12) + 's';
        const size = 1.5 + Math.random() * 2;
        p.style.width = size + 'px';
        p.style.height = size + 'px';
        p.style.opacity = 0.08 + Math.random() * 0.12;
        particlesContainer.appendChild(p);
    }
}

// ========== Phone Screen Carousel ==========
const screens = document.querySelectorAll('.screen-content');
if (screens.length > 1) {
    let currentScreen = 0;
    setInterval(() => {
        screens[currentScreen].classList.remove('active');
        currentScreen = (currentScreen + 1) % screens.length;
        screens[currentScreen].classList.add('active');
    }, 4000);
}

// ========== Smooth Scroll ==========
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            e.preventDefault();
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});
