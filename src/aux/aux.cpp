#include "aux.hpp"

namespace aux {

static std::unique_ptr<memtype[]> make_memory(long size)
{
    return std::unique_ptr<memtype[]>(new memtype[size]);
}


Memory::Memory(long size): _size(size)
{
    if (size > 0) {
        this->memory = make_memory(size);
    }
    else {
        this->memory = nullptr;
    }
}


void Memory::alloc(long size)
{
    this->_size = size;
    this->memory = make_memory(size);
}


static RTypeInfo const type_infos[] = {
    RTypeInfo(),
    TypeInfo<int>::make_info(),
    TypeInfo<long>::make_info(),
    TypeInfo<size_t>::make_info(),
    
    TypeInfo<int8_t>::make_info(),
    TypeInfo<int16_t>::make_info(),
    TypeInfo<int32_t>::make_info(),
    TypeInfo<int64_t>::make_info(),

    TypeInfo<uint8_t>::make_info(),
    TypeInfo<uint16_t>::make_info(),
    TypeInfo<uint32_t>::make_info(),
    TypeInfo<uint64_t>::make_info(),
    
    TypeInfo<float>::make_info(),
    TypeInfo<double>::make_info(),
    
    //TypeInfo<cpx64>::make_info(),
    //TypeInfo<cpx128>::make_info()
};


// return reference to type_info struct

RTypeInfo const& type_info(int const type)
{
    return type < 16 and type > 0 ? type_infos[type] : type_infos[0];
}


RTypeInfo const& type_info(dtype const type)
{
    return type_info(static_cast<int const>(type));
}


// aux namespace
}