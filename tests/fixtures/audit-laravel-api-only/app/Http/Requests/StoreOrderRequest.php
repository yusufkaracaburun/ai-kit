<?php
// Fixture FormRequest. Triggers L6.

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
{
    // L6: Validation duplicated across FormRequest + $casts + migration (🟠).
    // Same rule (max:255) encoded here, in Order::$casts, and in the migration column.
    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
        ];
    }
}
