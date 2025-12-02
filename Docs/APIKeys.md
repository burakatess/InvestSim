## API Keys & Konfigürasyon

| Sağlayıcı | Dosya / Anahtar | Not |
|-----------|-----------------|-----|
| TCMB EVDS | `Info.plist` → `EVDS_BASE_URL`, ayrıca `EVDS_API_KEY` (UserDefaults veya Secrets) | Döviz/kıymetli maden geçmişi için opsiyonel. |
| Metals.live | API anahtarı gerektirmez | Spot kıymetli maden verisi USD bazlı alınır. |
| exchangerate.host | Anahtar gerektirmez | Forex değerleri için `ForexRateClient` kullanır. |
| CoinGecko | Anahtar gerektirmez (rate limitli) | Binance’te olmayan kriptolar için yedek. |
| Yahoo Finance | Anahtar gerektirmez | Hisseler ve fonlar için sembol eşlemesi gerekir. |

> Eğer EVDS veya başka ücretli servis anahtarı kullanılacaksa, `Secrets.plist` içinde kaydedip `Info.plist` üzerinden `Bundle.main.object(forInfoDictionaryKey:)` ile okuyun. README'de paylaşıma açık olmayan anahtarları eklemeyin. 

