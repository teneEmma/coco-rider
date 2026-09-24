import { useEffect, useState } from 'react';
import { content, routes, type Locale } from './content';

/** Store links are set at build time; until the apps are published the buttons read "Coming soon". */
const storeLinks = {
  play: import.meta.env.VITE_PLAY_STORE_URL as string | undefined,
  apple: import.meta.env.VITE_APP_STORE_URL as string | undefined,
};

function initialLocale(): Locale {
  try {
    const stored = localStorage.getItem('coco-locale');
    if (stored === 'fr' || stored === 'en') return stored;
  } catch {
    // Storage blocked: use the browser language.
  }
  return navigator.language.startsWith('en') ? 'en' : 'fr';
}

function StoreButtons({ locale }: { locale: Locale }) {
  const t = content[locale];
  const buttons = [
    { key: 'play', label: t.stores.play, href: storeLinks.play },
    { key: 'apple', label: t.stores.apple, href: storeLinks.apple },
  ];
  return (
    <div className="stores">
      {buttons.map((b) => b.href ? (
        <a key={b.key} className="store" href={b.href} rel="noopener">{b.label}</a>
      ) : (
        <span key={b.key} className="store disabled" aria-disabled="true">
          {b.label}
          <small>{t.hero.soon}</small>
        </span>
      ))}
    </div>
  );
}

function RouteIllustration() {
  return (
    <svg className="illustration" viewBox="0 0 320 220" role="img" aria-label="Douala → Yaoundé">
      <path d="M40 170 C 110 170, 110 60, 180 70 S 260 40, 280 50" className="road" />
      <path d="M40 170 C 110 170, 110 60, 180 70 S 260 40, 280 50" className="road-dash" />
      <circle cx="40" cy="170" r="9" className="pin" />
      <circle cx="280" cy="50" r="9" className="pin" />
      <text x="40" y="200" textAnchor="middle" className="city">Douala</text>
      <text x="280" y="84" textAnchor="middle" className="city">Yaoundé</text>
      <g transform="translate(150 86)">
        <rect x="-26" y="-14" width="52" height="22" rx="8" className="car" />
        <circle cx="-14" cy="9" r="6" className="wheel" />
        <circle cx="14" cy="9" r="6" className="wheel" />
      </g>
    </svg>
  );
}

export default function App() {
  const [locale, setLocale] = useState<Locale>(initialLocale);
  const t = content[locale];

  useEffect(() => {
    document.documentElement.lang = locale;
    try {
      localStorage.setItem('coco-locale', locale);
    } catch {
      // Not persisted; fine.
    }
  }, [locale]);

  return (
    <>
      <header className="header">
        <a href="#top" className="logo">Coco Rider</a>
        <nav aria-label="Sections">
          <a href="#how">{t.nav.how}</a>
          <a href="#drivers">{t.nav.drivers}</a>
          <a href="#safety">{t.nav.safety}</a>
          <a href="#faq">{t.nav.faq}</a>
        </nav>
        <button
          type="button"
          className="lang"
          onClick={() => setLocale(locale === 'fr' ? 'en' : 'fr')}
          aria-label={locale === 'fr' ? 'Switch to English' : 'Passer en français'}
        >
          {locale === 'fr' ? 'EN' : 'FR'}
        </button>
      </header>

      <main id="top">
        <section className="hero">
          <div>
            <h1>{t.hero.title}</h1>
            <p className="lead">{t.hero.subtitle}</p>
            <StoreButtons locale={locale} />
          </div>
          <RouteIllustration />
        </section>

        <section id="how" className="section">
          <h2>{t.how.title}</h2>
          <ol className="steps">
            {t.how.steps.map((step, i) => (
              <li key={step.title} className="card">
                <span className="step-number" aria-hidden="true">{i + 1}</span>
                <h3>{step.title}</h3>
                <p>{step.text}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="section">
          <h2>{t.routes.title}</h2>
          <ul className="routes">
            {routes.map(([from, to]) => (
              <li key={`${from}-${to}`}>{from} <span aria-hidden="true">⇄</span><span className="sr-only">–</span> {to}</li>
            ))}
          </ul>
          <p className="muted">{t.routes.subtitle}</p>
        </section>

        <section id="drivers" className="section band">
          <div className="band-inner">
            <h2>{t.drivers.title}</h2>
            <p className="lead">{t.drivers.text}</p>
            <ul className="checks">
              {t.drivers.points.map((p) => <li key={p}>{p}</li>)}
            </ul>
          </div>
        </section>

        <section id="safety" className="section">
          <h2>{t.safety.title}</h2>
          <div className="grid">
            {t.safety.points.map((p) => (
              <div key={p.title} className="card">
                <h3>{p.title}</h3>
                <p>{p.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="faq" className="section">
          <h2>{t.faq.title}</h2>
          <div className="faq">
            {t.faq.items.map((item) => (
              <details key={item.q}>
                <summary>{item.q}</summary>
                <p>{item.a}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="section cta">
          <h2>{t.hero.title}</h2>
          <StoreButtons locale={locale} />
        </section>
      </main>

      <footer className="footer">{t.footer} · © {new Date().getFullYear()}</footer>
    </>
  );
}
