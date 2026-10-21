-- KVKK metinleri uygulama ayarlarından veri sorumlusu bilgileriyle tamamlanır.
-- Aydınlatma metni ve gizlilik politikası açık rıza/onay metni değildir.

insert into policy_documents (document_type, version, title, content, status)
values (
  'kvkk_notice',
  '2026-08-17',
  'KVKK Aydınlatma Metni',
  $kvkk$
{{APP_NAME}} KVKK AYDINLATMA METNİ

Yürürlük tarihi: {{EFFECTIVE_DATE}}

1. Veri sorumlusu
6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında veri sorumlusu {{DATA_CONTROLLER_NAME}}’dır.
Adres: {{DATA_CONTROLLER_ADDRESS}}
KVKK iletişim e-postası: {{KVKK_EMAIL}}
KEP: {{DATA_CONTROLLER_KEP}}
Telefon: {{DATA_CONTROLLER_PHONE}}

2. İşlenen kişisel veriler
Hizmetin kullanımına göre şu veri grupları işlenebilir:
• Kimlik ve profil: görünen ad, profil türü, isteğe bağlı cinsiyet, profil fotoğrafı, biyografi ve işletme bilgileri.
• İletişim: e-posta adresi, telefon numarası ve iletişim tercihleri.
• Hesap ve güvenlik: parola özeti (parolanın kendisi saklanmaz), oturum ve cihaz bilgileri, IP adresi, kullanıcı aracısı, doğrulama kayıtları ve güvenlik günlükleri.
• Konum ve adres: izin verilmesi hâlinde cihaz konumu; il, ilçe, mahalle, ilan konumu, hizmet mesafesi ve isteğe bağlı ayrıntılı adres. Ayrıntılı adres herkese açık gösterilmez; herkese açık harita konumu yaklaşıklaştırılabilir.
• İlan ve kullanım: ilan başlığı, açıklaması, kategori, ücret, müsaitlik, tercihler, fotoğraflar, favoriler, kayıtlı aramalar, değerlendirmeler ve şikâyetler.
• İletişim içeriği: platform içi mesajlar, mesaj ekleri ve bildirim kayıtları.
• Teknik veriler: çerez tercihleri, hata ve performans kayıtları, bildirim belirteçleri ve kötüye kullanım önleme kayıtları.

Özel nitelikli kişisel veri talep etmiyoruz. Kullanıcıların ilan, mesaj veya görsellere sağlık, biyometrik veri ya da benzeri özel nitelikli verileri yazmaması gerekir.

3. İşleme amaçları ve hukuki sebepler
Kişisel veriler;
• hesabı kurmak, oturumu yönetmek, ilan yayımlamak, arama/harita, favori ve mesajlaşma özelliklerini sunmak için KVKK m.5/2-c kapsamındaki sözleşmenin kurulması veya ifası,
• güvenlik, dolandırıcılık ve spam önleme, hata giderme, hizmet kalitesini ölçme ve hukuki uyuşmazlıklarda hakkın korunması için m.5/2-f kapsamındaki meşru menfaat,
• yetkili kurum taleplerini yanıtlamak ve mevzuattan doğan yükümlülükleri yerine getirmek için m.5/2-ç kapsamındaki hukuki yükümlülük,
• kullanıcının alenileştirdiği profil ve ilan bilgilerinin seçtiği görünürlük kapsamında sunulması için m.5/2-d,
• isteğe bağlı pazarlama iletişimi, zorunlu olmayan çerezler veya başka bir işleme şartına dayanmayan isteğe bağlı özellikler için ayrı ve geri alınabilir açık rıza
sebeplerine dayanılarak işlenir. Açık rıza, hizmetin zorunlu olmayan bölümleri için alınır ve geri çekilmesi geçmişteki hukuka uygun işlemleri etkilemez.

4. Toplama yöntemleri
Veriler; web sitesi ve mobil uygulamadaki formlar, cihaz izinleri, çerez/yerel depolama, API istekleri, mesajlaşma ve destek kanalları üzerinden otomatik veya kısmen otomatik yollarla; gerektiğinde yetkili mercilerden otomatik olmayan yollarla elde edilir.

5. Aktarım
Veriler yalnız amaçla sınırlı ve gerekli olduğu ölçüde; ilanı veya profili görüntüleyen diğer kullanıcılara, mesajlaştığınız karşı tarafa, barındırma/veritabanı/depolama, e-posta, SMS, anlık bildirim, harita, güvenlik ve teknik destek hizmeti sağlayan veri işleyenlere; hukuken gerekli olduğunda yetkili kamu kurumlarına ve yargı mercilerine aktarılabilir. Yurt dışına aktarım gerektiren bir hizmet devreye alınırsa KVKK m.9’daki uygun güvence veya diğer geçerli aktarım mekanizması kurulmadan aktarım yapılmaz ve güncel alıcı/hizmet sağlayıcı bilgisi bu metne yansıtılır.

6. Saklama ve silme
Veriler amaç için gerekli süre ve ilgili mevzuattaki zamanaşımı/saklama süreleri boyunca tutulur. Hesap kapandığında veya amaç ortadan kalktığında; devam eden uyuşmazlık, güvenlik olayı ya da yasal yükümlülük yoksa veriler silinir, yok edilir veya anonimleştirilir. Güvenlik günlükleri, iletişim kayıtları ve yedekler yalnız belirlenmiş sınırlı sürelerle ve erişim kısıtlı olarak saklanır.

7. KVKK m.11 kapsamındaki haklarınız
Kişisel verilerinizin işlenip işlenmediğini öğrenme; işlenmişse bilgi isteme; işleme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme; yurt içi/yurt dışı aktarılan üçüncü kişileri bilme; eksik veya yanlış verinin düzeltilmesini, şartları oluşmuşsa silinmesini/yok edilmesini ve bu işlemlerin aktarılan üçüncü kişilere bildirilmesini isteme; otomatik analiz sonucuna itiraz etme ve kanuna aykırı işleme nedeniyle zararın giderilmesini talep etme haklarına sahipsiniz.

Başvurunuzu uygulama veya webde Ayarlar > Hesap ve Gizlilik alanından ya da kimliğinizi doğrulamaya elverişli biçimde {{KVKK_EMAIL}} adresinden iletebilirsiniz. Yazılı başvurular {{DATA_CONTROLLER_ADDRESS}} adresine gönderilebilir. Başvurular en kısa sürede ve en geç 30 gün içinde sonuçlandırılır. Kimlik doğrulama için yalnız gerekli ek bilgiler istenir.

Bu metin bir açık rıza metni değildir; kişisel verilerin nasıl işlendiğine ilişkin aydınlatmadır.
  $kvkk$,
  'draft'
)
on conflict (document_type, version) do update
set title=excluded.title, content=excluded.content, updated_at=now();

insert into policy_documents (document_type, version, title, content, status)
values (
  'privacy_policy',
  '2026-08-17',
  'Gizlilik ve Veri Koruma Politikası',
  $privacy$
{{APP_NAME}} GİZLİLİK VE VERİ KORUMA POLİTİKASI

Son güncelleme: {{EFFECTIVE_DATE}}

Bu politika, {{APP_URL}} adresindeki web platformu ile aynı hesaba bağlı mobil uygulamanın gizlilik yaklaşımını açıklar. Veri sorumlusu {{DATA_CONTROLLER_NAME}}’dır. Ayrıntılı veri kategorileri, amaçlar, hukuki sebepler, alıcı grupları ve KVKK hakları KVKK Aydınlatma Metni’nde yer alır.

1. Gizlilik tasarımı
• Yalnız hizmet için gerekli veri istenir; isteğe bağlı alanlar açıkça belirtilir.
• Konum, kamera, galeri ve bildirim izinleri yalnız ilgili özellik kullanılırken istenir. İsteğe bağlı izni vermemek, o izin gerekmeyen temel özellikleri engellemez.
• Tam adres ve hassas konum varsayılan olarak herkese açık değildir. İlan harita konumu güvenlik amacıyla yaklaşık gösterilebilir.
• Parolalar geri döndürülemez güçlü özetleme yöntemiyle saklanır; oturumlar süreli ve iptal edilebilir belirteçlerle korunur.
• Dosya yüklemelerinde tür/boyut doğrulaması, görsel üst verisi temizleme ve erişim kontrolü uygulanır.
• Yetkili yönetim işlemleri rol bazlı erişim ve denetim kayıtlarıyla izlenir.

2. Hesap ve görünürlük
Görünen ad, profil fotoğrafı, biyografi, doğrulama durumu, puan ve ilanlarda seçilen yaklaşık konum diğer kullanıcılara gösterilebilir. Telefon numarası yalnız kullanıcı görünürlük ayarını açarsa giriş yapmış kullanıcılara gösterilir. İşletme profillerinde işletme adı ve kullanıcının yayımlamayı seçtiği işletme bilgileri görünür olabilir.

3. Konum
Mobil uygulama ve web tarayıcısı, yalnız kullanıcı izin verdiğinde konum isteyebilir. Kullanıcı konumu reddedebilir ve il/ilçe veya harita noktası seçerek devam edebilir. Arka planda sürekli konum takibi yapılmaz. Böyle bir özellik ileride sunulursa ayrı açıklama ve gerekli izin mekanizması kurulmadan etkinleştirilmez.

4. Mesajlar ve kullanıcı içeriği
Mesajlar yalnız konuşmanın tarafları ile güvenlik/moderasyon amacıyla yetkili ve görevli kişilerce erişilebilir. Kullanıcılar mesaj ve ilanlarda üçüncü kişilere ait kişisel verileri hukuki dayanak olmadan paylaşmamalıdır. Şikâyet hâlinde ilgili içerik, platform güvenliği için sınırlı olarak incelenebilir.

5. Çerezler ve benzer teknolojiler
Oturum, CSRF ve güvenlik çerezleri hizmetin çalışması için zorunludur. Analitik ve pazarlama amaçlı zorunlu olmayan teknolojiler varsayılan olarak kapalıdır ve ancak ayrı tercih verilirse etkinleştirilir. Tercih daha sonra Çerez Tercihleri alanından değiştirilebilir.

6. Hizmet sağlayıcılar ve aktarım
Teknik hizmet sağlayıcılar yalnız yazılı talimat, gizlilik ve güvenlik yükümlülükleri kapsamında veri işler. Yeni bir sağlayıcı eklenmeden önce veri konumu, erişim, alt işleyenler, saklama ve silme koşulları değerlendirilir. Yurt dışı aktarım varsa KVKK m.9 şartları sağlanır.

7. Saklama, güvenlik ihlali ve çocuklar
Veriler yalnız gerekli ve yasal süre boyunca saklanır. Erişim yetkileri düzenli gözden geçirilir; güvenlik olayı hâlinde olay müdahale süreci işletilir ve mevzuatın gerektirdiği bildirimler yapılır. Platform 18 yaş altındaki kişilere yönelik değildir; reşit olmayanlara ait veri tespit edilirse gerekli silme ve veli/vasi iletişim süreci uygulanır.

8. Tercihler ve başvurular
İletişim tercihleri ile çerez izinleri istenildiği zaman değiştirilebilir. Veri erişimi, düzeltme, silme ve itiraz talepleri web veya mobil uygulamadaki Hesap ve Gizlilik ekranından iletilebilir. İletişim: {{KVKK_EMAIL}}.

Politika önemli ölçüde değişirse yeni sürüm yayımlanır ve değişikliğin niteliğine göre uygulama içi bildirim yapılır. Yeni bir açık rıza gerektiren işlem, eski veya genel bir onaya dayanılarak başlatılmaz.
  $privacy$,
  'draft'
)
on conflict (document_type, version) do update
set title=excluded.title, content=excluded.content, updated_at=now();

insert into policy_documents (document_type, version, title, content, status)
values (
  'cookie_policy',
  '2026-08-17',
  'Çerez Politikası',
  $cookie$
{{APP_NAME}} ÇEREZ POLİTİKASI

Son güncelleme: {{EFFECTIVE_DATE}}

Web platformunda kullanılan teknolojiler:

1. Zorunlu çerezler
Oturum açma, CSRF koruması, yönetim güvenliği ve çerez tercihinin hatırlanması için zorunludur. Bu çerezler olmadan talep edilen güvenli hizmet sağlanamaz ve bu nedenle ayrıca açık rıza seçeneğine bağlı değildir.

2. Analitik çerezler
Ziyaret ve performans ölçümü için kullanılabilir. Varsayılan olarak kapalıdır; yalnız Çerez Tercihleri ekranından izin verilirse etkinleştirilir. Mevcut sürümde bir analitik sağlayıcı etkin değilse verilen tercih gelecekteki bir sağlayıcıyı kendiliğinden etkinleştirmez; sağlayıcı bilgisi politika güncellenmeden analitik başlatılmaz.

3. Pazarlama çerezleri
Kişiselleştirilmiş tanıtım veya yeniden hedefleme için kullanılabilir. Varsayılan olarak kapalıdır ve ayrı izin olmadan etkinleştirilmez.

4. Tercih yönetimi
Kullanıcı, sayfa altındaki “Çerez tercihleri” düğmesinden zorunlu olmayan çerezleri reddedebilir veya iznini geri çekebilir. Tarayıcı ayarlarından çerezleri silmek oturumu kapatabilir ve tercihlerin yeniden sorulmasına neden olabilir.

Çerezlerle ilişkili kişisel verilerin işlenmesine ilişkin veri sorumlusu, amaç, hukuki sebep, aktarım ve hak bilgileri KVKK Aydınlatma Metni’nde açıklanır. İletişim: {{KVKK_EMAIL}}.
  $cookie$,
  'draft'
)
on conflict (document_type, version) do update
set title=excluded.title, content=excluded.content, updated_at=now();

update policy_documents
set status='retired', updated_at=now()
where document_type in ('kvkk_notice','privacy_policy','cookie_policy')
  and version <> '2026-08-17'
  and status='published';

update policy_documents
set status='published', published_at=coalesce(published_at, now()), updated_at=now()
where document_type in ('kvkk_notice','privacy_policy','cookie_policy')
  and version='2026-08-17';
