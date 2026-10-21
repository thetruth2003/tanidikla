<?php

declare(strict_types=1);

namespace App\Core;

final class Router
{
    /** @var list<array{method: string, pattern: string, handler: callable}> */
    private array $routes = [];

    public function get(string $pattern, callable $handler): void
    {
        $this->add('GET', $pattern, $handler);
    }

    public function post(string $pattern, callable $handler): void
    {
        $this->add('POST', $pattern, $handler);
    }

    public function put(string $pattern, callable $handler): void
    {
        $this->add('PUT', $pattern, $handler);
    }

    public function delete(string $pattern, callable $handler): void
    {
        $this->add('DELETE', $pattern, $handler);
    }

    private function add(string $method, string $pattern, callable $handler): void
    {
        $this->routes[] = [
            'method' => $method,
            'pattern' => rtrim($pattern, '/') ?: '/',
            'handler' => $handler,
        ];
    }

    public function dispatch(Request $request): mixed
    {
        foreach ($this->routes as $route) {
            if ($route['method'] !== $request->method) {
                continue;
            }

            $parameterNames = [];
            $regex = preg_replace_callback(
                '/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/',
                static function (array $matches) use (&$parameterNames): string {
                    $parameterNames[] = $matches[1];
                    return '([^/]+)';
                },
                $route['pattern'],
            );
            if ($regex === null || !preg_match('#^' . $regex . '$#', $request->path, $matches)) {
                continue;
            }

            array_shift($matches);
            $parameters = [];
            foreach ($parameterNames as $index => $name) {
                $parameters[$name] = rawurldecode($matches[$index] ?? '');
            }

            return ($route['handler'])($request->withRouteParameters($parameters));
        }

        throw new HttpException(404, 'Sayfa veya API adresi bulunamadı.', 'not_found');
    }
}

