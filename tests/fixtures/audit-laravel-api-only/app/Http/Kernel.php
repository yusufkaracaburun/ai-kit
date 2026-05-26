<?php
// Kernel that trips L21.

namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

class Kernel extends HttpKernel
{
    // L21: TrimStrings / ConvertEmptyStringsToNull middleware removed from Kernel (🟡).
    // Both default Laravel global middlewares are intentionally absent here.
    protected $middleware = [
        \Illuminate\Http\Middleware\HandleCors::class,
        // \Illuminate\Foundation\Http\Middleware\TrimStrings::class,
        // \Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull::class,
    ];
}
