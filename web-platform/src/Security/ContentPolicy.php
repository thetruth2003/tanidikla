<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Config;
use App\Core\HttpException;

final class ContentPolicy
{
    /** Ambiguous marketplace words such as "mal" are intentionally excluded. */
    private const EXACT_WORDS = [
        'amk', 'amq', 'aq', 'oc', 'pic', 'orospu', 'kahpe', 'kaltak', 'pezevenk',
        'ibne', 'gavat', 'yarrak', 'amcik', 'siktir', 'sikik', 'gotveren',
        'dalyarak', 'gerizekali', 'serefsiz', 'haysiyetsiz', 'namussuz',
        'dangalak', 'fuck', 'fucker', 'fucking', 'bitch', 'cunt', 'motherfucker',
    ];

    /** Turkish suffixes and deliberately stretched spellings are caught by stems. */
    private const BLOCKED_STEMS = [
        'orospu', 'kahpe', 'kaltak', 'pezevenk', 'ibne', 'gavat', 'yarrak',
        'amcik', 'siktir', 'sikik', 'gotveren', 'dalyarak', 'gerizekali',
        'serefsiz', 'haysiyetsiz', 'namussuz', 'dangalak', 'fucker',
        'fucking', 'motherfucker',
    ];

    /** Punctuation, spaces and common leetspeak are ignored for these phrases. */
    private const BLOCKED_PHRASES = [
        'amina koy', 'amina koyayim', 'ananı sik', 'anani sik', 'seni sik',
        'orospu cocugu', 'orospu çocuğu', 'got veren', 'göt veren',
        'siktir git', 'fuck you', 'son of a bitch',
    ];

    public static function assertAcceptable(string $value, string $field = 'Metin'): void
    {
        if (!Config::bool('CONTENT_POLICY_ENABLED', true) || trim($value) === '') {
            return;
        }

        if (self::containsBlockedContent($value)) {
            throw new HttpException(
                422,
                $field . ' uygunsuz veya hakaret içeren bir ifade barındırıyor. Lütfen daha saygılı bir dille düzenle.',
                'inappropriate_content',
            );
        }
    }

    private static function containsBlockedContent(string $value): bool
    {
        $tokens = preg_split('/[^a-z0-9]+/', self::normalize($value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($tokens === []) {
            return false;
        }

        [$extraWords, $extraStems, $extraPhrases] = self::configuredRules();
        $exactWords = array_merge(self::EXACT_WORDS, $extraWords);
        $stems = array_merge(self::BLOCKED_STEMS, $extraStems);

        foreach ($tokens as $token) {
            foreach (self::tokenVariants($token) as $variant) {
                if (in_array($variant, $exactWords, true)) {
                    return true;
                }
                foreach ($stems as $stem) {
                    if (strlen($stem) >= 4 && str_starts_with($variant, $stem)) {
                        return true;
                    }
                }
            }
        }

        $compactPhrases = array_map(
            static fn (string $phrase): string => preg_replace('/[^a-z0-9]+/', '', self::normalize($phrase)) ?? '',
            array_merge(self::BLOCKED_PHRASES, $extraPhrases),
        );
        $compactPhrases = array_values(array_filter(array_unique($compactPhrases)));

        // Catch phrases without making every normal space irrelevant.
        $count = count($tokens);
        for ($start = 0; $start < $count; $start++) {
            $window = '';
            for ($end = $start; $end < min($count, $start + 4); $end++) {
                $window .= self::squashRepeats($tokens[$end]);
                if (in_array($window, $compactPhrases, true)) {
                    return true;
                }
            }
        }

        // Catch letter-by-letter obfuscation such as "a.m.k" or "o r o s p u".
        for ($start = 0; $start < $count; $start++) {
            $joined = '';
            for ($end = $start; $end < min($count, $start + 14); $end++) {
                if (strlen($tokens[$end]) > 2) {
                    break;
                }
                $joined .= self::squashRepeats($tokens[$end]);
                if (strlen($joined) >= 2 && in_array($joined, $exactWords, true)) {
                    return true;
                }
            }
        }

        return false;
    }

    /** @return array{0:list<string>,1:list<string>,2:list<string>} */
    private static function configuredRules(): array
    {
        $raw = Config::string('CONTENT_POLICY_EXTRA_BLOCKED');
        if (trim($raw) === '') {
            return [[], [], []];
        }

        $words = [];
        $stems = [];
        $phrases = [];
        foreach (preg_split('/[,;\r\n]+/', $raw, -1, PREG_SPLIT_NO_EMPTY) ?: [] as $rule) {
            $rule = trim(self::normalize($rule));
            if ($rule === '') {
                continue;
            }
            if (str_ends_with($rule, '*')) {
                $stem = rtrim(substr($rule, 0, -1));
                if (strlen($stem) >= 4) {
                    $stems[] = $stem;
                }
            } elseif (str_contains($rule, ' ')) {
                $phrases[] = $rule;
            } else {
                $words[] = $rule;
            }
        }

        return [array_values(array_unique($words)), array_values(array_unique($stems)), array_values(array_unique($phrases))];
    }

    /** @return list<string> */
    private static function tokenVariants(string $token): array
    {
        return array_values(array_unique([$token, self::squashRepeats($token)]));
    }

    private static function squashRepeats(string $value): string
    {
        return preg_replace('/(.)\1+/u', '$1', $value) ?? $value;
    }

    private static function normalize(string $value): string
    {
        // Convert Turkish uppercase before strtolower; works without mbstring.
        $value = strtr($value, [
            'Ç' => 'c', 'Ğ' => 'g', 'İ' => 'i', 'I' => 'i', 'Ö' => 'o', 'Ş' => 's', 'Ü' => 'u',
            'ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u',
        ]);
        $value = strtolower($value);

        return strtr($value, [
            '0' => 'o', '1' => 'i', '!' => 'i', '3' => 'e', '4' => 'a', '@' => 'a',
            '5' => 's', '$' => 's', '7' => 't', '+' => 't', '8' => 'b', '9' => 'g',
        ]);
    }
}
