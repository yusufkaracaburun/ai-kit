<?php
// Fixture model that trips L2, L22.

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// L2: God-Model > 300 LOC (🟠) — pretend this class has 412 LOC of mixed
// responsibilities (queries + business + casts + scopes + events + validation).
// Test asserts marker presence; the LOC heuristic is LLM-driven at audit time.

// L22: Eloquent model with empty $fillable + no $guarded (🔴) — mass-assignment open.
class Order extends Model
{
    // intentionally empty: no $fillable, no $guarded
}
