# Planlar Sekmesi - Takvim Odaklı UI Gereksinimleri

## 1. Ekran Haritası
1. `PlansHomeView`
   - Üst bilgi kartı (aktif plan sayısı, sonraki plan tarihi)
   - Takvim komponenti (ay görünümü)
   - "Yaklaşan Hatırlatmalar" dikey listesi
   - "Geçmiş" kısa listesi (son 3 tamamlanan)
2. `PlanDetailSheet`
   - Plan meta bilgileri, reminder offset özetleri
   - Hatırlatma mesajı ön izlemesi
   - Aksiyonlar: tamamla, ertele (skip), düzenle, pasif et.
3. `PlanEditorFlow`
   - Adım 1: Varlık + plan adı
   - Adım 2: Miktar & birim
   - Adım 3: Frekans & gün seçimi (takvim picker + haftalık selector)
   - Adım 4: Hatırlatma onay ekranı (offset, motivasyon tonu)
4. `CompletionSheet`
   - Seçilen tarih için “Planı tamamla” aksiyonu, isteğe bağlı not
   - "Bugün tamamlandı" / "Başka tarih seç" toggle

## 2. Ana Senaryolar
| Senaryo | Beklenen Davranış |
| --- | --- |
| Sekme açıldı | `PlansViewModel` aktif planları yükler, takvimi belirtilen aya kurar, scheduler’dan `nextDueDate` ve pending reminders verisini çeker. |
| Takvimde gün seçildi | Sağdaki liste sadece o güne denk gelen plan/hatırlatma kartlarını gösterir. |
| Hatırlatma kartı kaydırıldı | Quick actions: `Tamamlandı`, `Detay`, `Ertele (1 hafta)` |
| Plan düzenlendi | Repository update → Scheduler `reschedule()` → UI refresh |
| Plan pasifleştirildi | Kart listelerinden çıkar, takvim dot’u gri olur |
| Misafir kullanıcı | `GuestRestrictedView` + “Plan oluşturmak için kayıt ol” CTA |

## 3. UI Bileşenleri
### 3.1 Takvim
- SwiftUI `LazyVGrid` tabanlı aylık görünüm.
- Gün hücresinde maksimum 2 renkli dot (farklı asset tonları).
- “Bugün” için highlight.
- Ay değiştirme okları ve "Bugün" butonu.

### 3.2 Hatırlatma Kartı
- Sol tarafta asset ikonu, sağda metin.
- State rozetleri:
  - `Planned` (mavi)
  - `Today` (turuncu)
  - `Overdue` (kırmızı)
- CTA düğmeleri: "Tamamla" ve "Detay".

### 3.3 Geçmiş Listesi
- Son 3 completion, `PlanHistory`den gelir.
- “Tüm geçmişi gör” linki (ileride).

## 4. ViewModel Gereksinimleri (`PlansViewModel`)
- Kaynaklar: `PlansRepository`, `PlanReminderScheduler`, `MotivationMessageProvider`.
- Published alanlar:
  - `month: Date` (takvimde gösterilen)
  - `selectedDate: Date`
  - `calendarDays: [CalendarDayItem]` (UI dot bilgisiyle)
  - `upcomingReminders: [ReminderItem]`
  - `history: [PlanHistoryItem]`
  - `sheetState: PlanSheetState` (none/detail/editor/completion)
  - `isLoading`, `errorMessage`
- Fonksiyonlar:
  - `load()` / `refresh()`
  - `selectDay(_:)`
  - `completeReminder(_:)`
  - `skipReminder(_:)`
  - `openEditor(existingPlan:)`

## 5. Flow Breakdown
1. **Initial Load**
   - Repository → tüm planlar
   - Calendar builder → ay hücreleri + dot sayısı
   - Scheduler → `nextDueDate`/pending reminder snapshot
2. **Reminder Completion**
   - Kullanıcı karttaki “Tamamla”ya basar → `CompletionSheet`
   - Sheet: tarih + onay → `PlansRepository.appendHistory` + `PlanReminderScheduler.handleCompletion`
   - UI refresh + Toast.
3. **Creation Flow**
   - `floatingButton` → Editor Step 1
   - Son adımda `Create` → repository save → scheduler schedule → `selectedDate` planın `nextDueDate`’ine alınır.

## 6. Hata & Boş Durumlar
- Plan yoksa takvim yerine onboarding mesajı + “Plan Oluştur” butonu.
- Bildirim izni kapalıysa banner ("Hatırlatıcılar için bildirim iznini aç") ve Settings shortcut.
- Scheduler hatasında inline error + retry.

## 7. Açık Sorular
- Erteleme süresi sabit mi? (Öneri: tek tıkla 1 hafta ertele + manuel tarih seçimi). 
- Çoklu hatırlatma (ör. aynı gün iki plan) listede nasıl gruplanacak? (Öneri: asset bazlı kart). 

Bu gereksinimler doğrultusunda UI geliştirmesi sıradaki iterasyonda yapılacak.
