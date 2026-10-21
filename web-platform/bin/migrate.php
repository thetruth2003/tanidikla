<?php

declare(strict_types=1);

use App\Core\Database;

require dirname(__DIR__) . '/bootstrap.php';

$database = new Database();
$pdo = $database->connection();
$pdo->exec('create table if not exists schema_migrations (version text primary key, applied_at timestamptz not null default now())');

$files = glob(APP_ROOT . '/database/migrations/*.sql') ?: [];
sort($files);

foreach ($files as $file) {
    $version = basename($file);
    $exists = $database->fetchOne('select version from schema_migrations where version = :version', ['version' => $version]);
    if ($exists !== null) {
        fwrite(STDOUT, "Atlandı: {$version}\n");
        continue;
    }

    $sql = file_get_contents($file);
    if ($sql === false) {
        throw new RuntimeException('Migration okunamadı: ' . $file);
    }

    $database->transaction(static function (PDO $connection) use ($sql, $version): void {
        $connection->exec($sql);
        $statement = $connection->prepare('insert into schema_migrations (version) values (:version)');
        $statement->execute(['version' => $version]);
    });
    fwrite(STDOUT, "Uygulandı: {$version}\n");
}

