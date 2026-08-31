@extends('layouts.admin', ['title' => 'Create dataset | PicoRadar Control Plane'])
@section('content')
<h1 class="text-3xl font-semibold">Create dataset</h1><form class="mt-6 space-y-4" method="POST" action="{{ route('admin.datasets.store') }}">@csrf <input class="w-full rounded border p-2" name="key" placeholder="restrictions" required><input class="w-full rounded border p-2" name="title" placeholder="Title" required><input class="w-full rounded border p-2" type="number" min="1" name="schema_version" value="1" required><button class="rounded bg-slate-900 px-4 py-2 text-white">Create</button></form>
@endsection
