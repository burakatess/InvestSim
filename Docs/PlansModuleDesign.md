# Planlar Modülü - Veri Modeli ve Servis Mimarisi

## 1. Amaç
Planlar sekmesini portföy ve senaryo akışlarından tamamen ayrıştırıp tek görevi yatırım hatırlatıcısı olan bir takvim/hatırlatıcı modülü hâline getirmek. Kullanıcı bir varlık için tekrar eden “alım günü” tanımlayacak ve uygulama 3 gün & 1 gün öncesinde motivasyon mesajlarıyla bildirim gönderecek.

## 2. Kısıtlar & Varsayımlar
- Planlar modülü portföy verisi veya senaryo sonuçlarıyla eşleşmez; yalnızca kullanıcı tercihlerini saklar.
- Stratejiler Core Data üzerinden saklanır (mevcut `InvestSimModel`).
- Yerel bildirimler (`UNUserNotificationCenter`) kullanılacak; ileride push entegrasyonuna hazır olmalı.
- Kullanıcı misafir ise sadece tanıtım ekranı görür, plan oluşturamaz.

## 3. Veri Modeli
### 3.1 `PlanReminder` (eski `DCAPlan` güncellenecek)
| Alan | Tip | Açıklama |
| --- | --- | --- |
| `id` | UUID | Benzersiz kimlik |
| `title` | String | Kullanıcının planına verdiği isim |
| `assetCode` | String | `AssetCode` raw value (ALTIN, USD, vb.) |
| `amountValue` | Decimal | Alım miktarı |
| `amountUnit` | String | `gram`, `ons`, `try`, `usd`, `adet` gibi |
| `frequency` | String | `monthly`, `weekly`, `custom` |
| `dayOfMonth` | Int16 | Aylık ise ayın kaçıncı günü |
| `dayOfWeek` | Int16 | Haftalık ise haftanın günü (1-7) |
| `timeZoneIdentifier` | String | Kullanıcının TZ’si |
| `reminderOffsets` | Transformable `[Int16]` | Kaç gün önce hatırlatma gönderileceği (örn. [-3, -1]) |
| `motivationalTone` | String | `calm`, `coach`, `dataDriven` vb. |
| `messageTemplateId` | String | İçerik deposundaki şablon referansı |
| `nextDueDate` | Date | Bir sonraki “alım günü” |
| `lastCompletionDate` | Date? | Kullanıcının planı işaretlediği son tarih |
| `isActive` | Bool | Plan açık/kapatılmış mı |
| `createdAt` / `updatedAt` | Date | Zaman damgası |

### 3.2 `PlanReminderHistory`
Yeni entity; kullanıcı “tamamlandı” dediğinde kayıt oluşturur.
| Alan | Tip | Açıklama |
| id | UUID |
| planId | UUID | İlişkili plan |
| completionDate | Date | İşaretlenen tarih |
| note | String? | İsteğe bağlı kullanıcı notu |

### 3.3 `PlanNotificationRecord`
Opsiyonel auxiliary entity; hangi bildirimlerin sistem tarafından planlandığını tutar (tekrar planlama yaparken çakışmayı önlemek için).
| Alan | Tip | Açıklama |
| id | UUID |
| planId | UUID |
| fireDate | Date |
| offsetDays | Int16 | -3 veya -1 gibi |
| notificationId | String | `UNNotificationRequest` kimliği |
| state | String | `scheduled`, `sent`, `cancelled` |

## 4. Servisler
### 4.1 `PlansRepository`
Mevcut sınıf genişletilecek.
- CRUD: `createPlan`, `updatePlan`, `deletePlan`, `fetchActivePlans`.
- Transformable `reminderOffsets` alanı için encode/decode helpers.
- History yönetimi: `appendHistoryEntry(plan:completionDate:note:)`, `fetchHistory(for:limit:)`.

### 4.2 `PlanReminderScheduler`
Sorumluluklar:
1. Aktif planları okuyup `nextDueDate` güncellemek.
2. Her plan için offset listesine göre tetikleme tarihleri üretmek.
3. `NotificationService` aracılığıyla bildirim planlamak.
4. Kullanıcı planı tamamladığında veya plan kapandığında ilgili bildirimleri iptal etmek.

API taslağı:
```swift
final class PlanReminderScheduler {
    func scheduleAll()
    func schedule(plan: PlanReminder)
    func cancel(plan: PlanReminder)
    func reschedule(plan: PlanReminder)
    func handleCompletion(for plan: PlanReminder, completionDate: Date)
}
```

### 4.3 `PlanNotificationPipeline`
`NotificationManager` üstünde thin abstraction.
- Bildirim içeriğini `MotivationMessageProvider` ile üretir.
- 3 gün/1 gün offsetine özel mesaj şablonları.
- Kullanıcı ayarlarından (bildirim açık mı?) geçer.

### 4.4 `MotivationMessageProvider`
- `Resources/MotivationMessages.json` gibi bir kaynaktan şablon çeker.
- Parametreler: `assetCode`, `tone`, `offset`. Örnek template: “3 gün kaldı! \(assetName) hedefinde istikrarlı ilerliyorsun.”

## 5. Veri & İş Akışları
1. **Plan Oluşturma** → Repository kaydı → `nextDueDate` hesaplanır → Scheduler bildirimleri planlar.
2. **Hatırlatma Gönderme** → Notification center → kullanıcı uygulamaya geldiğinde “Planı tamamla” CTA.
3. **Tamamlama** → History kaydı + `lastCompletionDate` güncelleme → `nextDueDate` yeniden hesaplama → yeni bildirimleri planlama.
4. **Plan Durdurma/Silme** → Scheduler pending notification’ları iptal eder → kayıt pasiflenir.

## 6. Modülerlik
- Planlar view’ı yalnızca `PlansRepository` + `PlanReminderScheduler` + `MotivationMessageProvider` bağımlı olacak.
- Portföy veya senaryo container referansı gerekmez; RootTabView bu sekme için ayrı view model enjekte eder.

## 7. Açık Noktalar
- `reminderOffsets` varsayılanı [-3, -1]; kullanıcı özelleştirebilir mi? (V2’de sabit tutmak önerilir.)
- History listesi için maksimum saklama (örn. son 50 kayıt).
- Çoklu zaman dilimi desteği: `nextDueDate` hesaplarında `timeZoneIdentifier` kullanılmalı.
