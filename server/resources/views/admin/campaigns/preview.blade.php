@extends('layouts.admin',['title'=>'Vista previa C11 | PicoRadar'])
@section('content')
<div class="flex items-center justify-between gap-4"><div><h1 class="text-3xl font-semibold">Vista previa C11</h1><p class="mt-1 text-sm text-slate-600">{{$campaign->public_id}} · {{$campaign->operationalStatus(now())}}</p></div><a class="rounded border px-4 py-2" href="{{route('admin.campaigns.show',$campaign)}}">Volver</a></div>
<section class="mt-6 max-w-5xl overflow-hidden rounded border bg-white" aria-label="Vista previa de campana"><img class="block w-full object-cover" style="aspect-ratio:4/1" src="{{route('admin.campaigns.image',$campaign)}}" alt=""><div class="p-5"><p class="text-xs font-semibold uppercase text-slate-500">{{$campaign->eyebrow}}</p><h2 class="mt-2 text-2xl font-semibold">{{$campaign->title}}</h2><p class="mt-2 text-slate-700">{{$campaign->subtitle}}</p><span class="mt-4 inline-block rounded bg-slate-900 px-4 py-2 text-white">{{$campaign->cta_text}}</span></div></section>
<p class="mt-4 text-sm text-slate-600">Destino: <span class="break-all">{{$campaign->cta_url}}</span></p>
@endsection
