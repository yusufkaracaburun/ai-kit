<?php
// Fixture service. Trips L1, L3, L7, L12.

namespace App\Services;

// L3: Domain code importing Illuminate\Http\Request (🔴) — domain coupled to HTTP transport.
use Illuminate\Http\Request;
use App\Models\Order;
use App\Models\Customer;

// L7: Service-vs-Action-vs-Job confusion (🟠) — single-method *Service should be an Action.
class OrderService
{
    public function process(Request $request): void
    {
        // L1: Eloquent N+1 in loop (🔴) — relation-in-loop without eager-load.
        $orders = Order::all();
        foreach ($orders as $order) {
            $name = $order->customer->name;
        }

        // L12: Multi-tenant detected + query without tenant-scope (🔴) — raw ::query().
        $bleed = Order::query()->get();
    }
}
