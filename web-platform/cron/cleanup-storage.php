<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;

require dirname(__DIR__) . '/bootstrap.php';

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
if (Config::string('STORAGE_DRIVER', 'local') !== 'local') {
    fwrite(STDOUT, "Yerel depolama kullanılmadığı için atlandı.\n");
    exit;
}

$configured = Config::string('UPLOAD_PATH', 'storage/uploads');
$root = str_starts_with($configured, '/') || preg_match('/^[A-Za-z]:[\\\\\/]/', $configured)
    ? rtrim($configured, '/\\')
    : APP_ROOT . '/' . trim($configured, '/\\');
$rootReal = realpath($root);
if ($rootReal === false || !is_dir($rootReal)) {
    fwrite(STDOUT, "Depolama klasörü bulunamadı.\n");
    exit;
}

$database = new Database();
$knownRows = $database->fetchAll("select storage_key from media_objects where storage_driver = 'local'");
$known = array_fill_keys(array_map(static fn (array $row): string => (string) $row['storage_key'], $knownRows), true);
$minimumAge = max(0, Config::int('STORAGE_ORPHAN_MIN_AGE_SECONDS', 86400));
$cutoff = time() - $minimumAge;
$deleted = 0;
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($rootReal, FilesystemIterator::SKIP_DOTS),
    RecursiveIteratorIterator::CHILD_FIRST,
);
foreach ($iterator as $item) {
    if (!$item->isFile() || $item->getFilename() === '.gitkeep' || $item->getMTime() > $cutoff) {
        continue;
    }
    $absolute = $item->getPathname();
    if (!str_starts_with($absolute, $rootReal . DIRECTORY_SEPARATOR)) {
        continue;
    }
    $relative = str_replace('\\', '/', substr($absolute, strlen($rootReal) + 1));
    if (isset($known[$relative])) {
        continue;
    }
    if (@unlink($absolute)) {
        $deleted++;
    }
}

fwrite(STDOUT, "Silinen sahipsiz dosya: {$deleted}\n");
