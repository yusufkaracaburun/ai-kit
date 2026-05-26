<?php
// Fixture controller. Trips L4, L9 (NOT L14 — that's api-only-only).

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Inertia\Inertia;
use App\Models\Order;

class OrderController extends Controller
{
    // L9: Controller method > 25 LOC (🟠).
    // No L14 here — full-stack returns via Inertia, not raw Eloquent JSON.
    public function index()
    {
        return Inertia::render('Orders/Index', [
            'orders' => Order::all(),
        ]);
    }

    // L4: FormRequest absent on POST (🟠).
    public function store(Request $request)
    {
        Order::create($request->all());
        return redirect()->route('orders.index');
    }

    public function destroy(Order $order)
    {
        $order->delete();
        return redirect()->route('orders.index');
    }
}
