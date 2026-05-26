<?php
// Config that trips L18.

return [
    // L18: Sanctum/Passport not configured but routes/api.php non-trivial (🟠, api-only).
    // The api guard intentionally uses the session driver instead of sanctum.
    'guards' => [
        'api' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
    ],
];
