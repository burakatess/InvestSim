# InvestSimulator Supabase Backend

## 🏗️ Mimari Özet

```
iOS App → Supabase Edge Functions → prices_latest / prices_history
                ↑
        Cron Jobs (her 30-60sn)
                ↓
    Binance / Yahoo / FX / Metals API
```

## 📁 Dosya Yapısı

```
backend/supabase/
├── migrations/
│   └── 001_complete_schema.sql   # 7 tablo + indexler + RLS
├── seed/
│   └── 001_assets.sql            # 64 varlık (crypto, stock, etf, fx, metal)
└── functions/
    ├── _shared/
    │   ├── supabase.ts           # Shared client + helpers
    │   └── providers/
    │       ├── interface.ts      # PriceProvider interface
    │       ├── binance.ts        # Crypto prices
    │       ├── yahoo.ts          # Stocks & ETFs
    │       ├── fx.ts             # Forex rates
    │       └── metals.ts         # Precious metals
    ├── prices-latest/            # GET /prices-latest
    ├── prices-history/           # GET /prices-history
    ├── portfolio-value/          # GET /portfolio-value
    ├── forecast-get/             # GET /forecast-get (stub)
    ├── cron-crypto-prices/       # 30sn - Binance
    ├── cron-stocks-etfs-prices/  # 60sn - Yahoo
    ├── cron-fx-metals-prices/    # 60sn - FX/Metals
    └── cron-backfill-history/    # Günlük 03:00 UTC
```

## 🚀 Deployment

### 1. Migration Çalıştır
```bash
cd backend/supabase
supabase db push
```

### 2. Seed Data Yükle
```bash
psql $DATABASE_URL -f seed/001_assets.sql
```

### 3. Edge Functions Deploy
```bash
supabase functions deploy prices-latest
supabase functions deploy prices-history
supabase functions deploy portfolio-value
supabase functions deploy forecast-get
supabase functions deploy cron-crypto-prices
supabase functions deploy cron-stocks-etfs-prices
supabase functions deploy cron-fx-metals-prices
supabase functions deploy cron-backfill-history
```

### 4. Cron Jobs Kur (pg_cron veya harici)

Supabase Dashboard → SQL Editor:
```sql
-- Crypto: Her 30 saniye
SELECT cron.schedule('crypto-prices', '*/30 * * * * *', $$
  SELECT net.http_post(
    'https://YOUR_PROJECT.supabase.co/functions/v1/cron-crypto-prices',
    '{}',
    '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'
  );
$$);

-- Stocks/ETFs: Her dakika
SELECT cron.schedule('stocks-prices', '* * * * *', $$
  SELECT net.http_post(
    'https://YOUR_PROJECT.supabase.co/functions/v1/cron-stocks-etfs-prices',
    '{}',
    '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'
  );
$$);

-- FX/Metals: Her dakika
SELECT cron.schedule('fx-metals-prices', '* * * * *', $$
  SELECT net.http_post(
    'https://YOUR_PROJECT.supabase.co/functions/v1/cron-fx-metals-prices',
    '{}',
    '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'
  );
$$);

-- Backfill: Her gün 03:00 UTC
SELECT cron.schedule('backfill-history', '0 3 * * *', $$
  SELECT net.http_post(
    'https://YOUR_PROJECT.supabase.co/functions/v1/cron-backfill-history',
    '{}',
    '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'
  );
$$);
```

## 📊 API Endpoints

| Endpoint | Açıklama |
|----------|----------|
| `GET /prices-latest` | Tüm güncel fiyatlar |
| `GET /prices-latest?symbols=BTCUSDT,AAPL` | Seçili semboller |
| `GET /prices-history?symbol=BTCUSDT&range=3m` | Tarihsel OHLCV |
| `GET /portfolio-value?portfolio_id=uuid` | Portföy değeri |
| `GET /forecast-get?symbol=BTCUSDT&horizon=3m` | ML tahminleri |

## 🔐 Güvenlik

- RLS aktif: Kullanıcılar sadece kendi portföylerini görebilir
- Fiyat tabloları herkese açık (read-only)
- Service Role sadece cron joblar için kullanılır

## 📈 Ölçeklenebilirlik

| Metrik | Mevcut | Gelecek |
|--------|--------|---------|
| Varlıklar | 64 | 1000+ |
| Kullanıcılar | 5.000 | 50.000+ |
| Güncelleme | 30-60sn | 10-15sn |
