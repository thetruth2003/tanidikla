<?php

declare(strict_types=1);

use App\Core\Database;

require dirname(__DIR__) . '/bootstrap.php';

$database = new Database();
$files = glob(APP_ROOT . '/database/seeds/*.sql') ?: [];
sort($files);

foreach ($files as $file) {
    $sql = file_get_contents($file);
    if ($sql === false) {
        throw new RuntimeException('Seed okunamadı: ' . $file);
    }
    $database->connection()->exec($sql);
    fwrite(STDOUT, 'Yüklendi: ' . basename($file) . "\n");
}

