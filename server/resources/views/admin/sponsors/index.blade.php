@extends('layouts.admin',['title'=>'Patrocinadores | PicoRadar'])
@section('content')
<div class="flex items-center justify-between gap-4"><div><h1 class="text-3xl font-semibold">Patrocinadores</h1><p class="mt-1 text-sm text-slate-600">Contactos privados y campanas asociadas.</p></div><a class="rounded bg-slate-900 px-4 py-2 text-white" href="{{route('admin.sponsors.create')}}">Nuevo patrocinador</a></div>
<div class="mt-6 overflow-x-auto rounded border bg-white"><table class="w-full text-left text-sm"><thead class="bg-slate-50"><tr><th class="p-3">Nombre</th><th class="p-3">Estado</th><th class="p-3">Campanas</th><th class="p-3">Accion</th></tr></thead><tbody>@forelse($sponsors as $sponsor)<tr class="border-t"><td class="p-3 font-medium">{{$sponsor->name}}</td><td class="p-3">{{$sponsor->status->value}}</td><td class="p-3">{{$sponsor->campaigns_count}}</td><td class="p-3"><a class="underline" href="{{route('admin.sponsors.show',$sponsor)}}">Abrir</a></td></tr>@empty<tr><td class="p-6 text-slate-500" colspan="4">No hay patrocinadores.</td></tr>@endforelse</tbody></table></div>
<div class="mt-4">{{$sponsors->links()}}</div>
@endsection
