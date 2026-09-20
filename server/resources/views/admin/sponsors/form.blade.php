@extends('layouts.admin',['title'=>'Patrocinador | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">{{$sponsor->exists?'Editar':'Nuevo'}} patrocinador</h1>
@if($errors->any())<p class="mt-4 rounded border border-red-200 bg-red-50 p-3 text-red-800">{{$errors->first()}}</p>@endif
<form class="mt-6 grid max-w-3xl gap-4 rounded border bg-white p-5" method="POST" action="{{$action}}">@csrf @if($method==='PUT')@method('PUT')@endif
<label>Nombre<input required maxlength="255" name="name" value="{{old('name',$sponsor->name)}}"></label>
<label>Contacto privado<input maxlength="255" name="contact_name" value="{{old('contact_name',$sponsor->contact_name)}}"></label>
<label>Correo privado<input maxlength="320" type="email" name="contact_email" value="{{old('contact_email',$sponsor->contact_email)}}"></label>
<label>Telefono privado<input maxlength="64" name="contact_phone" value="{{old('contact_phone',$sponsor->contact_phone)}}"></label>
<label>Notas privadas<textarea maxlength="4000" name="notes">{{old('notes',$sponsor->notes)}}</textarea></label>
<div><button class="rounded bg-slate-900 px-4 py-2 text-white">Guardar</button></div>
</form>
@endsection
