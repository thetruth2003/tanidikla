<?php

declare(strict_types=1);

use App\Core\Database;
use App\Core\Request;
use App\Domain\AdminService;

require dirname(__DIR__) . '/bootstrap.php';

$database = new Database();
$actor = $database->fetchOne("select id, role from users where role = 'super_admin' limit 1");
if ($actor === null) {
    throw new RuntimeException('Test için yönetici hesabı bulunamadı.');
}

$service = new AdminService($database);
$request = Request::capture();
$categoryId = 'codex_admin_test_category';
$reportId = '00000000-0000-4000-8000-000000009999';
$listingOwnerId = '00000000-0000-4000-8000-00000000d101';
$userDeleteId = '00000000-0000-4000-8000-00000000d102';
$hardDeleteListingId = '00000000-0000-4000-8000-00000000d201';
$cascadeListingId = '00000000-0000-4000-8000-00000000d202';

$cleanup = static function () use ($database, $categoryId, $reportId, $listingOwnerId, $userDeleteId, $hardDeleteListingId, $cascadeListingId): void {
    $database->statement('delete from privacy_requests where user_id in (:first,:second)', ['first'=>$listingOwnerId,'second'=>$userDeleteId]);
    $database->statement('delete from listings where id in (:first,:second)', ['first'=>$hardDeleteListingId,'second'=>$cascadeListingId]);
    $database->statement(
        "delete from admin_audit_logs where (entity_type='listing' and entity_id in (:listing_first,:listing_second)) or (entity_type='user' and entity_id in (:user_first,:user_second))",
        ['listing_first'=>$hardDeleteListingId,'listing_second'=>$cascadeListingId,'user_first'=>$listingOwnerId,'user_second'=>$userDeleteId],
    );
    $database->statement('delete from users where id in (:first,:second)', ['first'=>$listingOwnerId,'second'=>$userDeleteId]);
    $database->statement(
        "delete from admin_audit_logs where entity_type = 'category' and entity_id = :id",
        ['id' => $categoryId],
    );
    $database->statement('delete from categories where id = :id', ['id' => $categoryId]);
    $database->statement(
        "delete from admin_audit_logs where entity_type = 'report' and entity_id = :id",
        ['id' => $reportId],
    );
    $database->statement('delete from reports where id = :id', ['id' => $reportId]);
};

$cleanup();
try {
    $dashboard = $service->dashboard();
    $reports = $service->reports();
    $categories = $service->categories();

    $created = $service->createCategory([
        'id' => $categoryId,
        'label' => 'Geçici Test Kategorisi',
        'sort_order' => 999,
        'is_active' => true,
        'is_selectable' => true,
    ], $actor, $request);

    $service->updateCategory($categoryId, [
        'label' => 'Güncellenmiş Test Kategorisi',
        'sort_order' => 998,
        'is_active' => true,
        'is_selectable' => true,
        'is_open_ended' => false,
    ], $actor, $request);
    $deleted = $service->deleteCategory($categoryId, $actor, $request);

    $reportFixture = $database->fetchOne(
        "select l.id as listing_id, u.id as reporter_id
         from listings l cross join users u
         where u.id <> l.owner_id
           and not exists (
             select 1 from reports r
             where r.reporter_id = u.id and r.listing_id = l.id and r.status in ('open','reviewing')
           )
         limit 1"
    );
    if ($reportFixture === null) throw new RuntimeException('Şikâyet testi için uygun kayıt bulunamadı.');
    $database->statement(
        "insert into reports (id,reporter_id,listing_id,reason,details)
         values (:id,:reporter,:listing,'spam','Yönetim konsolu geçici smoke testi')",
        ['id'=>$reportId,'reporter'=>$reportFixture['reporter_id'],'listing'=>$reportFixture['listing_id']],
    );
    $service->updateReport($reportId, [
        'status'=>'reviewing',
        'priority'=>'high',
        'admin_note'=>'Test inceleme notu',
    ], $actor, $request);
    $updatedReport=$database->fetchOne('select status,priority,admin_note from reports where id=:id',['id'=>$reportId]);

    $fixtureCategory = $database->fetchOne('select id from categories where is_active and is_selectable order by sort_order limit 1');
    if ($fixtureCategory === null) throw new RuntimeException('Kalıcı silme testi için kategori bulunamadı.');
    foreach ([[$listingOwnerId,'hard-delete-owner@example.test','Silme Testi Bir'],[$userDeleteId,'hard-delete-user@example.test','Silme Testi İki']] as [$id,$email,$name]) {
        $database->statement('insert into users (id,email,password_hash) values (:id,:email,:password)', [
            'id'=>$id,'email'=>$email,'password'=>password_hash('Smoke-Test-123!',PASSWORD_ARGON2ID),
        ]);
        $database->statement("insert into profiles (user_id,display_name,city,district) values (:id,:name,'Ankara','Çankaya')", ['id'=>$id,'name'=>$name]);
    }
    foreach ([[$hardDeleteListingId,$listingOwnerId,'codex-hard-delete-listing'],[$cascadeListingId,$userDeleteId,'codex-hard-delete-user-listing']] as [$id,$owner,$slug]) {
        $database->statement("insert into listings (id,owner_id,slug,listing_type,status,public_latitude,public_longitude,location_precision,public_city,public_district,public_neighborhood) values (:id,:owner,:slug,'service_offer','active',39.92,32.85,'neighborhood','Ankara','Çankaya','Test')", ['id'=>$id,'owner'=>$owner,'slug'=>$slug]);
        $database->statement("insert into listing_items (listing_id,category_id,page_index,title,description,pricing_unit) values (:listing,:category,0,'Kalıcı silme smoke ilanı','Yalnız otomatik test için oluşturulan geçici ilan.','fixed')", ['listing'=>$id,'category'=>$fixtureCategory['id']]);
    }
    $database->statement("insert into privacy_requests (user_id,request_type,details) values (:id,'correction','Geçici kalıcı silme smoke testi')", ['id'=>$userDeleteId]);
    $listingDeleteResult = $service->permanentlyDeleteListing($hardDeleteListingId,'Otomatik smoke testi','KALICI OLARAK SİL',$actor,$request);
    $userDeleteResult = $service->permanentlyDeleteUser($userDeleteId,'Otomatik smoke testi','KALICI OLARAK SİL',$actor,$request);

    $result = [
        'dashboard' => isset($dashboard['users'], $dashboard['reports_by_reason']),
        'reports_query' => is_array($reports),
        'category_query' => count($categories) > 0,
        'category_create' => ($created['id'] ?? null) === $categoryId,
        'category_delete' => ($deleted['deleted'] ?? false) === true,
        'report_update' => ($updatedReport['status'] ?? null) === 'reviewing'
            && ($updatedReport['priority'] ?? null) === 'high'
            && ($updatedReport['admin_note'] ?? null) === 'Test inceleme notu',
        'listing_hard_delete' => ($listingDeleteResult['deleted'] ?? false) === true
            && $database->fetchOne('select id from listings where id=:id',['id'=>$hardDeleteListingId]) === null
            && $database->fetchOne('select id from users where id=:id',['id'=>$listingOwnerId]) !== null,
        'user_hard_delete' => ($userDeleteResult['deleted'] ?? false) === true
            && $database->fetchOne('select id from users where id=:id',['id'=>$userDeleteId]) === null
            && $database->fetchOne('select id from listings where id=:id',['id'=>$cascadeListingId]) === null
            && $database->fetchOne('select id from privacy_requests where user_id=:id',['id'=>$userDeleteId]) === null,
    ];
    if (in_array(false, $result, true)) {
        throw new RuntimeException('Yönetim konsolu smoke testi başarısız.');
    }
    fwrite(STDOUT, json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL);
} finally {
    $cleanup();
}
