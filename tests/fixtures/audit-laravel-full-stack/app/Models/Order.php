<?php
// Fixture model that trips L2, L22.

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// L2: God-Model > 300 LOC (🟠).
// L22: Eloquent model with empty $fillable + no $guarded (🔴).
class Order extends Model
{
    // intentionally empty: no $fillable, no $guarded
}
