// Landing page motion: scroll reveals, parallax, header state, hero mouse depth, smooth FAQ.
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    }
  }, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
  document.querySelectorAll('[data-reveal]').forEach((el) => io.observe(el));

  const header = document.querySelector('.top');
  const bar = document.querySelector('.progress');
  const parallax = [...document.querySelectorAll('[data-parallax]')];
  let ticking = false;
  const onScroll = () => {
    ticking = false;
    const y = scrollY;
    header.classList.toggle('scrolled', y > 10);
    const max = document.documentElement.scrollHeight - innerHeight;
    bar.style.transform = `scaleX(${max > 0 ? y / max : 0})`;
    if (reduce) return;
    for (const el of parallax) {
      const r = el.getBoundingClientRect();
      if (r.bottom < -200 || r.top > innerHeight + 200) continue;
      const offset = (r.top + r.height / 2 - innerHeight / 2) / innerHeight;
      el.style.setProperty('--py', `${(-offset * el.dataset.parallax).toFixed(1)}px`);
    }
  };
  addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });
  onScroll();

  const hero = document.querySelector('.hero');
  const phones = document.querySelector('.hero-phones');
  if (phones && !reduce && matchMedia('(pointer: fine)').matches) {
    hero.addEventListener('pointermove', (e) => {
      const r = phones.getBoundingClientRect();
      phones.style.setProperty('--mx', ((e.clientX - r.left) / r.width - 0.5).toFixed(3));
      phones.style.setProperty('--my', ((e.clientY - r.top) / r.height - 0.5).toFixed(3));
    });
    hero.addEventListener('pointerleave', () => {
      phones.style.setProperty('--mx', 0);
      phones.style.setProperty('--my', 0);
    });
  }

  document.querySelectorAll('.faq details').forEach((d) => {
    const summary = d.querySelector('summary');
    const answer = d.querySelector('.answer');
    summary.addEventListener('click', (e) => {
      e.preventDefault();
      if (d.classList.contains('is-open')) {
        d.classList.remove('is-open');
        if (reduce) { d.open = false; return; }
        answer.animate([{ height: `${answer.scrollHeight}px`, opacity: 1 }, { height: '0px', opacity: 0 }],
          { duration: 280, easing: 'ease-in' }).onfinish = () => { if (!d.classList.contains('is-open')) d.open = false; };
      } else {
        d.open = true;
        d.classList.add('is-open');
        if (reduce) return;
        answer.animate([{ height: '0px', opacity: 0 }, { height: `${answer.scrollHeight}px`, opacity: 1 }],
          { duration: 420, easing: 'cubic-bezier(0.2, 0.7, 0.2, 1)' });
      }
    });
  });
})();
