<?php
// Trait for unused scope (trips L5).

namespace App\Models;

trait OrderScopes
{
    // L5: Unused scope (🟡) — no callsite outside this module.
    public function scopeOrphaned($query)
    {
        return $query->whereNull('owner_id');
    }
}
