<?php
// Fixture: routes/web.php for audit-laravel-full-stack.
// Markers L13, L15, L17 live here (api-only-only L14/L16/L18 intentionally absent).

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\OrderController;

// L13: Route in api middleware group without throttle: (🔴) — applies in both modes.
Route::middleware('api')->group(function () {
    Route::get('/orders', [OrderController::class, 'index']);
});

// L15: List endpoint without paginate() / cursorPaginate() (🔴) — see OrderController::index.

// L17: Mutating route without auth middleware (🔴).
Route::post('/orders', [OrderController::class, 'store']);
Route::delete('/orders/{order}', [OrderController::class, 'destroy']);
