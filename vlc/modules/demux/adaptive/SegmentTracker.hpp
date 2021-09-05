/*
 * SegmentTracker.hpp
 *****************************************************************************
 * Copyright (C) 2014 - VideoLAN and VLC authors
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef SEGMENTTRACKER_HPP
#define SEGMENTTRACKER_HPP

#include "StreamFormat.hpp"
#include "playlist/CodecDescription.hpp"
#include "playlist/Role.hpp"

#include <vlc_common.h>
#include <list>

namespace adaptive
{
    class ID;
    class SharedResources;

    namespace http
    {
        class AbstractConnectionManager;
        class ChunkInterface;
    }

    namespace logic
    {
        class AbstractAdaptationLogic;
        class AbstractBufferingLogic;
    }

    namespace playlist
    {
        class BaseAdaptationSet;
        class BaseRepresentation;
        class SegmentChunk;
    }

    using namespace playlist;
    using namespace logic;
    using namespace http;

    class TrackerEvent
    {
        public:
            enum class Type
            {
                Discontinuity,
                RepresentationSwitch,
                FormatChange,
                SegmentChange,
                BufferingStateUpdate,
                BufferingLevelChange,
                PositionChange,
            };
            TrackerEvent() = delete;
            virtual ~TrackerEvent() = 0;
            Type getType() const;

        protected:
            TrackerEvent(Type t);

        private:
            Type type;
    };

    class DiscontinuityEvent : public TrackerEvent
    {
        public:
            DiscontinuityEvent();
            virtual ~DiscontinuityEvent()  = default;
    };

    class RepresentationSwitchEvent : public TrackerEvent
    {
        public:
            RepresentationSwitchEvent() = delete;
            RepresentationSwitchEvent(BaseRepresentation *, BaseRepresentation *);
            virtual ~RepresentationSwitchEvent() = default;

            BaseRepresentation *prev;
            BaseRepresentation *next;
    };

    class FormatChangedEvent : public TrackerEvent
    {
        public:
            FormatChangedEvent() = delete;
            FormatChangedEvent(const StreamFormat *);
            virtual ~FormatChangedEvent() = default;

            const StreamFormat *format;
    };

    class SegmentChangedEvent : public TrackerEvent
    {
        public:
            SegmentChangedEvent() = delete;
            SegmentChangedEvent(const ID &, vlc_tick_t, vlc_tick_t, vlc_tick_t = VLC_TICK_INVALID);
            virtual ~SegmentChangedEvent() = default;

            const ID *id;
            vlc_tick_t displaytime;
            vlc_tick_t starttime;
            vlc_tick_t duration;
    };

    class BufferingStateUpdatedEvent : public TrackerEvent
    {
        public:
            BufferingStateUpdatedEvent() = delete;
            BufferingStateUpdatedEvent(const ID &, bool);
            virtual ~BufferingStateUpdatedEvent() = default;

            const ID *id;
            bool enabled;
    };

    class BufferingLevelChangedEvent : public TrackerEvent
    {
        public:
            BufferingLevelChangedEvent() = delete;
            BufferingLevelChangedEvent(const ID &,
                                       vlc_tick_t, vlc_tick_t, vlc_tick_t, vlc_tick_t);
            virtual ~BufferingLevelChangedEvent() = default;

            const ID *id;
            vlc_tick_t minimum;
            vlc_tick_t maximum;
            vlc_tick_t current;
            vlc_tick_t target;
    };

    class PositionChangedEvent : public TrackerEvent
    {
        public:
            PositionChangedEvent();
            virtual ~PositionChangedEvent() = default;
    };

    class SegmentTrackerListenerInterface
    {
        public:
            virtual void trackerEvent(const TrackerEvent &) = 0;
            virtual ~SegmentTrackerListenerInterface() = default;
    };

    class SegmentTracker
    {
        public:
            SegmentTracker(SharedResources *,
                           AbstractAdaptationLogic *,
                           const AbstractBufferingLogic *,
                           BaseAdaptationSet *);
            ~SegmentTracker();

            class Position
            {
                public:
                    Position();
                    Position(BaseRepresentation *, uint64_t);
                    Position & operator++();
                    bool isValid() const;
                    std::string toString() const;
                    uint64_t number;
                    BaseRepresentation *rep;
                    bool init_sent;
                    bool index_sent;
            };

            StreamFormat getCurrentFormat() const;
            void getCodecsDesc(CodecDescriptionList *) const;
            const Role & getStreamRole() const;
            void reset();
            ChunkInterface* getNextChunk(bool, AbstractConnectionManager *);
            bool setPositionByTime(vlc_tick_t, bool, bool);
            void setPosition(const Position &, bool);
            bool setStartPosition();
            Position getStartPosition() const;
            vlc_tick_t getPlaybackTime(bool = false) const; /* Current segment start time if selected */
            bool getMediaPlaybackRange(vlc_tick_t *, vlc_tick_t *, vlc_tick_t *) const;
            vlc_tick_t getMinAheadTime() const;
            void notifyBufferingState(bool) const;
            void notifyBufferingLevel(vlc_tick_t, vlc_tick_t, vlc_tick_t, vlc_tick_t) const;
            void registerListener(SegmentTrackerListenerInterface *);
            void updateSelected();
            bool bufferingAvailable() const;

        private:
            class ChunkEntry
            {
                public:
                    ChunkEntry();
                    ChunkEntry(SegmentChunk *c, Position p, vlc_tick_t s, vlc_tick_t d, vlc_tick_t dt);
                    bool isValid() const;
                    SegmentChunk *chunk;
                    Position pos;
                    vlc_tick_t displaytime;
                    vlc_tick_t starttime;
                    vlc_tick_t duration;
            };
            std::list<ChunkEntry> chunkssequence;
            ChunkEntry prepareChunk(bool switch_allowed, Position pos,
                                    AbstractConnectionManager *connManager) const;
            void resetChunksSequence();
            void setAdaptationLogic(AbstractAdaptationLogic *);
            void notify(const TrackerEvent &) const;
            bool first;
            bool initializing;
            Position current;
            Position next;
            StreamFormat format;
            SharedResources *resources;
            AbstractAdaptationLogic *logic;
            const AbstractBufferingLogic *bufferingLogic;
            BaseAdaptationSet *adaptationSet;
            std::list<SegmentTrackerListenerInterface *> listeners;
    };
}

#endif // SEGMENTTRACKER_HPP
