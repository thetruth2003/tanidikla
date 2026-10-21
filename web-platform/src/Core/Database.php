<?php

declare(strict_types=1);

namespace App\Core;

use PDO;
use PDOException;
use PDOStatement;
use RuntimeException;
use Throwable;

final class Database
{
    private ?PDO $pdo = null;

    public function connection(): PDO
    {
        if ($this->pdo instanceof PDO) {
            return $this->pdo;
        }

        $driver = Config::string('DB_DRIVER', 'pgsql');
        if ($driver !== 'pgsql') {
            throw new RuntimeException('Bu proje PostgreSQL için yapılandırılmıştır.');
        }

        $dsn = sprintf(
            'pgsql:host=%s;port=%d;dbname=%s',
            Config::string('DB_HOST', '127.0.0.1'),
            Config::int('DB_PORT', 5432),
            Config::string('DB_NAME', 'ankara_services'),
        );

        try {
            $this->pdo = new PDO(
                $dsn,
                Config::string('DB_USER', 'ankara_app'),
                Config::string('DB_PASSWORD'),
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                ],
            );
        } catch (PDOException $exception) {
            throw new RuntimeException('Veritabanı bağlantısı kurulamadı.', 0, $exception);
        }

        return $this->pdo;
    }

    /** @param array<string, mixed> $parameters */
    public function statement(string $sql, array $parameters = []): PDOStatement
    {
        $statement = $this->connection()->prepare($sql);
        $statement->execute($parameters);
        return $statement;
    }

    /** @param array<string, mixed> $parameters
     *  @return array<string, mixed>|null
     */
    public function fetchOne(string $sql, array $parameters = []): ?array
    {
        $row = $this->statement($sql, $parameters)->fetch();
        return $row === false ? null : $row;
    }

    /** @param array<string, mixed> $parameters
     *  @return list<array<string, mixed>>
     */
    public function fetchAll(string $sql, array $parameters = []): array
    {
        /** @var list<array<string, mixed>> $rows */
        $rows = $this->statement($sql, $parameters)->fetchAll();
        return $rows;
    }

    /** @template T
     *  @param callable(PDO): T $callback
     *  @return T
     */
    public function transaction(callable $callback): mixed
    {
        $pdo = $this->connection();
        $pdo->beginTransaction();
        try {
            $result = $callback($pdo);
            $pdo->commit();
            return $result;
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $exception;
        }
    }
}
