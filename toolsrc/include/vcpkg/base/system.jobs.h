#pragma once

#include <functional>

namespace vcpkg::System::Jobs
{
    void post(std::function<void()>&& f, std::string&& description);

    void join_all();
}
