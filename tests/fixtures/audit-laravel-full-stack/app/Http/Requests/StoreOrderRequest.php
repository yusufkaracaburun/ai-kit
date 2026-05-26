<?php
// Fixture FormRequest. Triggers L6.

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
{
    // L6: Validation duplicated across FormRequest + $casts + migration (🟠).
    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
        ];
    }
}
