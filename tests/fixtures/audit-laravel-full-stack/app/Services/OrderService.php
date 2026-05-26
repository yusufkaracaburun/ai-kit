<?php
// Fixture service. Trips L1, L3, L7, L12.

namespace App\Services;

// L3: Domain code importing Illuminate\Http\Request (🔴).
use Illuminate\Http\Request;
use App\Models\Order;

// L7: Service-vs-Action-vs-Job confusion (🟠).
class OrderService
{
    public function process(Request $request): void
    {
        // L1: Eloquent N+1 in loop (🔴).
        $orders = Order::all();
        foreach ($orders as $order) {
            $name = $order->customer->name;
        }

        // L12: Multi-tenant detected + query without tenant-scope (🔴).
        $bleed = Order::query()->get();
    }
}
