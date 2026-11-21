@extends('layouts.admin', ['title' => 'Partner inquiries | PicoRadar Control Plane'])

@section('content')
    <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
            <h1 class="text-3xl font-semibold">Partner inquiries</h1>
            <p class="mt-2 text-slate-600">Voluntary requests sent to PicoRadar. Unapproved records are retained for at most 180 days.</p>
        </div>
        <a class="rounded-md border border-slate-300 px-3 py-2 text-sm font-medium" href="{{ route('admin.partner-inquiries.audit') }}">Status audit</a>
    </div>

    <form class="mt-6 flex items-end gap-3" method="GET">
        <label class="text-sm font-medium">Status
            <select class="mt-1 block rounded-md border-slate-300" name="status">
                <option value="">All</option>
                @foreach($statuses as $status)
                    <option value="{{ $status->value }}" @selected(request('status') === $status->value)>{{ $status->label() }}</option>
                @endforeach
            </select>
        </label>
        <button class="rounded-md border border-slate-300 px-3 py-2 text-sm font-medium" type="submit">Filter</button>
    </form>

    <div class="mt-6 overflow-x-auto rounded border bg-white">
        <table class="min-w-full text-left text-sm">
            <thead class="bg-slate-100 text-slate-600"><tr><th class="p-3">Received</th><th class="p-3">Business</th><th class="p-3">Contact</th><th class="p-3">Category</th><th class="p-3">City</th><th class="p-3">Status</th></tr></thead>
            <tbody>
            @forelse($inquiries as $inquiry)
                <tr class="border-t align-top">
                    <td class="p-3">{{ $inquiry->created_at?->toAtomString() }}<br><span class="text-slate-500">{{ $inquiry->public_id }}</span></td>
                    <td class="p-3 font-medium">{{ $inquiry->business_name }}@if($inquiry->message)<p class="mt-1 max-w-sm font-normal text-slate-600">{{ $inquiry->message }}</p>@endif</td>
                    <td class="p-3">{{ $inquiry->contact_name }}<br><a href="mailto:{{ $inquiry->email }}">{{ $inquiry->email }}</a><br>{{ $inquiry->phone }}</td>
                    <td class="p-3">{{ $inquiry->category }}</td>
                    <td class="p-3">{{ $inquiry->city }}</td>
                    <td class="p-3">
                        <form method="POST" action="{{ route('admin.partner-inquiries.status', $inquiry) }}">
                            @csrf @method('PUT')
                            <select class="rounded-md border-slate-300" name="status" aria-label="Status for {{ $inquiry->public_id }}">
                                @foreach($statuses as $status)<option value="{{ $status->value }}" @selected($inquiry->status === $status)>{{ $status->label() }}</option>@endforeach
                            </select>
                            <button class="mt-2 block rounded-md bg-slate-900 px-3 py-2 font-medium text-white" type="submit">Save</button>
                        </form>
                    </td>
                </tr>
            @empty
                <tr><td class="p-3" colspan="6">No partner inquiries.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    <div class="mt-4">{{ $inquiries->links() }}</div>
@endsection
