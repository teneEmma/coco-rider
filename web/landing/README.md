# Coco Rider landing page (React)

Presents the app (French/English) and links to the stores.

```bash
npm ci
npm run dev
npm test
VITE_PLAY_STORE_URL=https://play.google.com/store/apps/details?id=... \
VITE_APP_STORE_URL=https://apps.apple.com/app/... npm run build   # without them the buttons say "coming soon"
```

`dist/` is deployed by the CDK stack (`infra/`).
