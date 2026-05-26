<?php
// Fixture: routes/api.php for audit-laravel-api-only.
// Markers L13, L15, L16, L17 live here.

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\OrderController;

// L13: API route without throttle: middleware (🔴).
Route::get('/orders', [OrderController::class, 'index']);

// L15: List endpoint without paginate() / cursorPaginate() (🔴) — see OrderController::index.

// L16: API routes missing /api/v{N}/ prefix (🟠, api-only) — no Route::prefix('v1') wrapper.

// L17: Mutating route without auth middleware (🔴).
Route::post('/orders', [OrderController::class, 'store']);
Route::delete('/orders/{order}', [OrderController::class, 'destroy']);
