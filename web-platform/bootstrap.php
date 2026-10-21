<?php

declare(strict_types=1);

use App\Core\Environment;

define('APP_ROOT', __DIR__);

spl_autoload_register(static function (string $class): void {
    $prefix = 'App\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = APP_ROOT . '/src/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($path)) {
        require $path;
    }
});

$composerAutoload = APP_ROOT . '/vendor/autoload.php';
if (is_file($composerAutoload)) {
    require $composerAutoload;
}

Environment::load(APP_ROOT . '/.env');
date_default_timezone_set('UTC');

