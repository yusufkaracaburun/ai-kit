<?php
// Fixture controller. Trips L4, L9, L14.

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Order;

class OrderController extends Controller
{
    // L9: Controller method > 25 LOC (🟠) — pretend this body is 40 LOC.
    // L14: API endpoint returning Eloquent model directly (no JsonResource) (🟠, api-only).
    public function index()
    {
        return Order::all();
    }

    // L4: FormRequest absent on POST (🟠) — accepts raw Request instead of typed StoreOrderRequest.
    public function store(Request $request)
    {
        return Order::create($request->all());
    }

    public function destroy(Order $order)
    {
        $order->delete();
        return response()->noContent();
    }
}
